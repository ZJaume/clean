# Try to fix the wiki titles between ='s
# Remove the ones that have a lot of =, mostly garbage
sed "/===+/d" \
 | sed -E "s/==+([^\t]+)==+//g"
