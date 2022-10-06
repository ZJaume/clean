sed -E "s/Artigo ([0-9]+)\.?o/Artigo \1º/g" \
    | sed -E "s/Artigo ([0-9]+)\.º/Artigo \1º/g"
