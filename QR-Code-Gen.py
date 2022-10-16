#!/usr/bin/env python3
import qrcode
img = qrcode.make("https://github.com/SagerChowdary/scripts")
img.save("out.jpg")
