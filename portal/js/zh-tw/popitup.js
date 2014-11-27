function popitup(url) {
    var newwindow = window.open(url, 'name', 'height=480,width=480');
    if (window.focus) { newwindow.focus(); }
    return false;
}

function gotourl(url) {
    // for IE 6.0
    if (window.event) {
        window.event.returnValue = false;
    }
    window.location = url;

    return false;
}
