// ubu-setup: enable userChrome.css (see chrome/userChrome.css)
//
// This is the only pref this file needs. Colours live in the stylesheet, and
// they must be literals: var(--custom-prop) references do not resolve in the
// chrome document, and an unresolved var() voids the whole declaration
// silently instead of falling back.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
