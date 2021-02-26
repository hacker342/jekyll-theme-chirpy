DEST=_site
URL_IGNORE=cdn.jsdelivr.net

if [[ -n $1 && -d $1 ]]; then
  DEST=$1
fi

bundle exec htmlproofer $DEST \
  --disable-external \
  --check-html \
  --empty_alt_ignore \
  --allow_hash_href \
  --url_ignore $URL_IGNORE
