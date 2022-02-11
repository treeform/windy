import windy, std/options, pixie

let imgMaybe = getClipboardImage()

if imgMaybe.isNone:
    echo "No image in clipboard"
else:
    let img = imgMaybe.get
    echo "Width: ", img.width, " Height: ", img.height
    let pngImg = encodeImage(img, FileFormat.ffPng)
    writeFile("clipboard_image.png", pngImg)