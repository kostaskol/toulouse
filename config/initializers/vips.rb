# Uploads are untrusted, and libvips would otherwise hand them to ImageMagick,
# poppler and others while sniffing. Only the accepted formats get parsed.
Vips.block("VipsForeignLoad", true)
%w[VipsForeignLoadJpeg VipsForeignLoadPng VipsForeignLoadWebp].each { |loader| Vips.block(loader, false) }
