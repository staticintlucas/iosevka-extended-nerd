#!/usr/bin/env bash

set -euxo pipefail

ver="v15.5.1" # refers to a git tag
nerd_ver="v2.1.0"

node_ver() {
  local str="$(node --version)"
  echo "$(cut -d. -f1 <<< ${str#v})"
}

[ "$(node_ver)" -ge "14" ] || \
  { echo "NodeJS 14.0 or later is required to build Iosevka"; exit 1; }
command -v npm > /dev/null || \
  { echo "npm is required to build Iosevka"; exit 1; }
command -v ttfautohint > /dev/null || \
  { echo "ttfautohint is required to build Iosevka"; exit 1; }
command -v python3 > /dev/null || \
  { echo "FontForge is required to build Nerd Fonts"; exit 1; }

echo "Downloading Iosevka..."
if [ ! -d "iosevka-$ver" ]; then
  mkdir -p "iosevka-$ver-tmp"
  curl -fsSL "https://github.com/be5invis/Iosevka/archive/refs/tags/$ver.tar.gz" | \
    tar -xzC "iosevka-$ver-tmp" --strip-components=1
  mv "iosevka-$ver-tmp" "iosevka-$ver"
fi

echo "Building Iosevka..."
cp "private-build-plans.toml" "iosevka-$ver/"
pushd "iosevka-$ver"
npm install

echo "Building Iosevka Extended..."
npm run build -- ttf::iosevka-extended-nerd; echo
echo "Building Iosevka Extended Term..."
npm run build -- ttf::iosevka-extended-term-nerd; echo
popd

echo "Downloading Nerd Font Patcher..."
if [ ! -d "nerd-fonts-$nerd_ver" ]; then
  mkdir -p "nerd-fonts-$nerd_ver-tmp"
  git clone --filter=blob:none --no-checkout --depth 1 --sparse \
    --branch "$nerd_ver" https://github.com/ryanoasis/nerd-fonts "nerd-fonts-$nerd_ver-tmp"
  pushd "nerd-fonts-$nerd_ver-tmp"
  git sparse-checkout add src/glyphs
  git checkout "$nerd_ver"
  popd
  mv "nerd-fonts-$nerd_ver-tmp" "nerd-fonts-$nerd_ver"
fi

echo "Patching fonts..."
cp -r "iosevka-$ver/dist/iosevka-extended-nerd/ttf/." "nerd-fonts-$nerd_ver/unpatched"
cp -r "iosevka-$ver/dist/iosevka-extended-term-nerd/ttf/." "nerd-fonts-$nerd_ver/unpatched"
pushd "nerd-fonts-$nerd_ver"
if [ ! -d patched ]; then
  mkdir -p patched-tmp
  for file in unpatched/*.ttf; do
    fontforge -script font-patcher --complete --careful --outputdir=patched-tmp $file
  done
  for file in unpatched/*.ttf; do
    fontforge -script font-patcher --complete --careful --outputdir=patched-tmp $file
  done
  for file in patched-tmp/*.ttf; do
    mv "$file" "$(echo "$file" | tr [:upper:] [:lower:] | sed -e 's/ /-/g' | sed -e 's/-nerd-font-complete//g')"
  done
  mv patched-tmp patched
fi

popd

cp -r "nerd-fonts-$nerd_ver/patched" "iosevka-extended-nerd"
