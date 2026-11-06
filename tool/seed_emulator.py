import json, urllib.request, base64, io, datetime as dt
from PIL import Image, ImageDraw, ImageFont
op = urllib.request.build_opener(urllib.request.ProxyHandler({}))
P = "http://127.0.0.1:8080/v1/projects/demo-ijm-disposal/databases/(default)/documents"
def req(url, data=None, method="POST", auth=True):
    r = urllib.request.Request(url, data=json.dumps(data).encode() if data else None, method=method,
        headers={"Content-Type":"application/json", **({"Authorization":"Bearer owner"} if auth else {})})
    return json.loads(op.open(r).read() or b"{}")
def val(v):
    if isinstance(v,bool): return {"booleanValue":v}
    if isinstance(v,int): return {"integerValue":str(v)}
    if isinstance(v,float): return {"doubleValue":v}
    if isinstance(v,dt.datetime): return {"timestampValue":v.strftime("%Y-%m-%dT%H:%M:%SZ")}
    if v is None: return {"nullValue":None}
    return {"stringValue":v}
def put(path, fields): req(f"{P}/{path}", {"fields":{k:val(v) for k,v in fields.items()}}, "PATCH")
def thumb(c1, c2, label):
    im = Image.new("RGB",(480,360)); d = ImageDraw.Draw(im)
    for y in range(360):
        t=y/360; d.line([(0,y),(480,y)], fill=tuple(int(a+(b-a)*t) for a,b in zip(c1,c2)))
    d.ellipse([300,-60,560,200], fill=tuple(min(255,x+30) for x in c1))
    try: f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 54)
    except: f = ImageFont.load_default()
    d.text((240,180), label, fill="white", font=f, anchor="mm")
    b=io.BytesIO(); im.save(b,"JPEG",quality=72); return base64.b64encode(b.getvalue()).decode()

AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1"
def user(email, password, name, verified=True):
    u = req(f"{AUTH}/accounts:signUp?key=demo",
            {"email": email, "password": password, "displayName": name, "returnSecureToken": True}, auth=False)
    if verified:
        req(f"{AUTH}/projects/demo-ijm-disposal/accounts:update",
            {"localId": u["localId"], "emailVerified": True})
    return u["localId"]

admin_uid = user("admin@ijm.org", "admin123", "Disposal Admin")
put(f"admins/{admin_uid}", {"email": "admin@ijm.org"})
user("staff@ijm.org", "staff123", "Test Staff")           # verified staff member
now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
put("settings/auction", {"title":"IJM Kenya — Disposal of Assets 2026", "startsAt": now-dt.timedelta(hours=2),
    "endsAt": now+dt.timedelta(days=1, hours=5, minutes=42),
    "maxPerItemPerPerson": 2, "maxTotalPerPerson": 3})
items = [
  ("Dell Latitude Laptop","Core i5, 8GB RAM, battery fair",8,6,15000,(19,73,126),(27,153,139),"LAPTOP"),
  ("Office Swivel Chair","Black mesh, adjustable height",20,15,1500,(124,92,219),(19,73,126),"CHAIR"),
  ("HP LaserJet Printer","Needs new toner cartridge",3,1,4500,(231,111,81),(242,165,65),"PRINTER"),
  ("Executive Desk","Mahogany finish, 3 drawers",4,0,6000,(11,37,69),(26,110,142),"DESK"),
  ("Samsung 24\" Monitor","Full HD, minor scratches",10,10,5000,(42,157,143),(19,73,126),"MONITOR"),
  ("Water Dispenser","Hot & cold, working",2,2,3000,(26,110,142),(124,92,219),"WATER"),
]
ids=[]
for i,(n,desc,q,r,p,c1,c2,lab) in enumerate(items):
    iid=f"item{i}"; ids.append((iid,n,p))
    put(f"items/{iid}", {"name":n,"description":desc,"quantity":q,"remaining":r,"price":p,
        "imageBase64":thumb(c1,c2,lab),"createdAt":now-dt.timedelta(days=1,minutes=-i)})
bids=[("Grace Wanjiru",0,1,90),("Peter Otieno",1,2,80),("Mercy Achieng",3,2,70),("James Mwangi",2,2,55),
      ("Faith Njeri",1,2,40),("Brian Kiprop",3,2,30),("Grace Wanjiru",1,1,20),("Daniel Mutua",0,1,8)]
tallies = {}
for j,(name,ii,q,mins) in enumerate(bids):
    iid,n,p=ids[ii]
    email = name.lower().replace(" ", ".") + "@ijm.org"
    uid = "seed-" + email.split("@")[0]
    put(f"bids/bid{j}", {"itemId":iid,"itemName":n,"bidderName":name,"email":email,"quantity":q,"unitPrice":p,
        "uid":uid,"createdAt":now-dt.timedelta(minutes=mins)})
    t = tallies.setdefault(uid, {"name":name,"email":email,"total":0,"items":{}})
    t["total"] += q; t["items"][iid] = t["items"].get(iid,0) + q
    if j % 3 != 2:  # mark some as paid / collected
        put(f"bidStatus/bid{j}", {"paid": True, "paidAt": now-dt.timedelta(minutes=mins-5),
            "collected": j % 3 == 0, "note": f"M-Pesa ref QK{j}7XY2" if j % 2 == 0 else ""})
for uid,t in tallies.items():
    req(f"{P}/bidders/{uid}", {"fields":{"name":val(t["name"]),"email":val(t["email"]),"total":val(t["total"]),
        "items":{"mapValue":{"fields":{k:val(v) for k,v in t["items"].items()}}}}}, "PATCH")
print("seeded; admin = admin@ijm.org / admin123, staff = staff@ijm.org / staff123")
