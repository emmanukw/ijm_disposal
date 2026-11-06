/// App-wide constants. Change these to suit your deployment.
const currency = 'KES';
const orgName = 'IJM';

/// Name of the site (browser tab, header, default title).
const appTitle = 'IJM Kenya Items Disposal';

/// Short name shown next to the logo in the top bar.
const brandName = 'IJM Kenya';

/// Organisation logo shown in the top bar and sign-in page.
/// Put the file at this path (PNG with a transparent background works best).
/// If the file is missing, a gavel icon is shown instead.
const logoAsset = 'assets/images/ijm_logo.png';

/// Only verified email addresses on this domain may use the site
/// (admins listed in the `admins` collection are exempt).
/// If you change it, also change `staffDomainRegex` in firestore.rules.
const allowedEmailDomain = 'ijm.org';

bool isAllowedEmail(String? email) =>
    email != null &&
    email.trim().toLowerCase().endsWith('@$allowedEmailDomain');
