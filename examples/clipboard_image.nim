import windy, pixie

let img = getClipboardImage()

if img.isNil:
    echo "No image in clipboard"
else:
    echo "Width: ", img.width, " Height: ", img.height
    let pngImg = encodeImage(img, FileFormat.ffPng)
    writeFile("clipboard_image.png", pngImg)