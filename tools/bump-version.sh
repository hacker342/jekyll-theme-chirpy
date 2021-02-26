set -eu

META_FILE="_data/meta.yml"

_latest_tag="$(git describe --abbrev=0)"

_version_field="version: $_latest_tag"

if [[ ! -f $META_FILE ]]; then
  echo "name: Chirpy" > $META_FILE
  echo "$_version_field" >> $META_FILE
else
  sed -i "s/^version:.*/$_version_field/g" $META_FILE
fi

if [[ -n $(git status $META_FILE -s) ]]; then
  git add $META_FILE
  git commit -m "Bump version to $_latest_tag"
fi
