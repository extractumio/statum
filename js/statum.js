const statumUri = '/statum.txt';

function getOperatingSystem() {
    const userAgent = window.navigator.userAgent;

    if (/Mac OS X|Macintosh/.test(userAgent)) {
        return 'macos';
    } else if (/iPhone|iPad|iPod/.test(userAgent)) {
        return 'ios';
    } else if (/Windows|Win32|Win64/.test(userAgent)) {
        return 'win';
    } else if (/Android/.test(userAgent)) {
        return 'android';
    } else if (/Linux/.test(userAgent)) {
        return 'linux';
    } else {
        return '';
    }
}

function isLocalStorageAvailable() {
    try {
        localStorage.setItem('test', 'test');
        localStorage.removeItem('test');
        return true;
    } catch(e) {
        return false;
    }
}

/**
 * Function to get a cookie value by name
 * @param {string} name
 * @returns {string|null}
 */
function getCookie(name) {
    let value = "; " + document.cookie;
    let parts = value.split("; " + name + "=");
    if (parts.length === 2) return parts.pop().split(";").shift();
    return null;
}

/**
 * Function to set a cookie
 * @param {string} name
 * @param {string} value
 * @param {number} days
 */
function setCookie(name, value, days) {
    let expires = "";
    if (days) {
        let date = new Date();
        date.setTime(date.getTime() + (days*24*60*60*1000));
        expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (value || "") + expires + "; path=/";
}

/**
 * Function to generate a UID
 * @returns {string}
 */
function generateUID() {
    // This UID is based on timestamp + random number. This should be unique enough for most use cases.
    // If you require a more unique ID, consider integrating a library or another method.
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
}

function statumSend() {
    // Getting the current URI and Referer
    let currentUri = encodeURIComponent(window.location.href);
    let referer = encodeURIComponent(document.referrer);

    // Get or Set UID
    let UID;
    if (isLocalStorageAvailable()) {
        UID = localStorage.getItem('UID');
        if (!UID) {
            UID = generateUID();
            localStorage.setItem('UID', UID);
        }
    } else {
        UID = getCookie('UID');
        if (!UID) {
            UID = generateUID();
            setCookie('UID', UID, 3650); // setting cookie to expire in 3650 days
        }
    }

    // Creating the URL to which the request will be sent
    let url = statumUri + '?uri=' + currentUri + '&r=' + referer + '&uid=' + UID + '&t=' + Date.now() + '&s=' + screen.width + 'x' + screen.height + '&c=' + navigator.cookieEnabled + '&l=' + navigator.language + '&os=' + getOperatingSystem();

    // Creating a new XMLHttpRequest object
    let xhr = new XMLHttpRequest();

    // Configuring the HEAD request
    xhr.open('HEAD', url, true);

    // Sending the HEAD request
    xhr.send();

    // Handling the response
    xhr.onload = function() {
        if (xhr.status === 200) {
        } else {
        }
    };
}

document.addEventListener('DOMContentLoaded', (event) => {
    statumSend();
});
