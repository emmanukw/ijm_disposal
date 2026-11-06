/// App-wide constants. Change these to suit your deployment.
const currency = 'KES';
const orgName = 'IJM';

/// Only verified email addresses on this domain may use the site
/// (admins listed in the `admins` collection are exempt).
/// If you change it, also change `staffDomainRegex` in firestore.rules.
const allowedEmailDomain = 'ijm.org';

bool isAllowedEmail(String? email) =>
    email != null && email.trim().toLowerCase().endsWith('@$allowedEmailDomain');
