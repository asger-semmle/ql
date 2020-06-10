export function validateHtml(html) {
    let i = 0;
    while ((i = html.indexOf('<', i)) !== -1) {
        if (html.substring(i).startsWith('<script')) { // NOT OK
            return false;
        }
        if (html.substring(i).toLowerCase().startsWith('<script')) { // OK - still bad but out of scope
            return false;
        }
    }
    return true;
}

function getHtmlTags(html) {
    return [ html.substring(Math.random(), Math.random()) ];
}

export function validateHtml2(html) {
    for (let tag of getHtmlTags(html)) {
        if (isUnsafeTag(tag)) { return false; }
        if (isUnsafeTag2(tag)) { return false; }
        if (isSafeTag(tag)) { continue; }
        if (hasSpecialParsingSemantics(tag)) { return false; }
    }
    return true;
}

const badTagNames = ['script', 'style'];
function isUnsafeTag(tag) {
    return badTagNames.includes(tag); // NOT OK
}
function isUnsafeTag2(tag) {
    return badTagNames.includes(tag.toLowerCase()); // OK - still bad but out of scope
}

export function isUnsafeTagUncalled(tag) {
    return badTagNames.includes(tag); // OK - no call site
}

const safeTagNames = ['ol', 'li'];
export function isSafeTag(tag) {
    return safeTagNames.includes(tag); // OK
}

const specialTagNames = ['script', 'p', 'style'];
export function hasSpecialParsingSemantics(tag) {
    return specialTagNames.includes(tag); // OK - not a security check
}

export function validateUrl1(url) {
    if (url.startsWith('javascript:')) return false; // NOT OK
    return true;
}
export function validateUrl2(url) {
    if (url.toLowerCase().startsWith('javascript:')) return false; // OK - still bad but out of scope
    return true;
}
export function validateUrl3(url) {
    if (/^(javascript:|data:)/.test(url)) return false; // NOT OK [INCONSISTENCY]
    return true;
}
export function validateUrl4(url) {
    if (/^(javascript:|data:)/i.test(url)) return false; // OK - still bad but out of scope
    return true;
}
export function validateUrl5(url) {
    if (/^(javascript:|data:)$/.test(url.protocol)) return false; // NOT OK
    return true;
}
export function validateUrl6(url) {
    if (/^(javascript:|data:)$/i.test(url.protocol)) return false; // OK - still bad but out of scope
    return true;
}
