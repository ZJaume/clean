# Truecase capes corpus which is entirely lowercased
# also restore Starting capital letter

sed -E 's/(^|\t)(\w)/\1\u\2/g'
