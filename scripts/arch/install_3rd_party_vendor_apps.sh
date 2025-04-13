#!/usr/bin/env bash

# Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

if [[ $(id -u) -eq 0 ]]; then
  echo "Please don't run this script as root"
  exit 1
fi

ANDROID_STUDIO_VERSION="2024.3.1.14"
SMARTGIT_VERSION="24_1_3"


#
# Install Android Studio
#
install_android_studio () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  tmp_file="$(mktemp)"
  curl -sSL -o "${tmp_file}" "https://dl.google.com/dl/android/studio/ide-zips/${ANDROID_STUDIO_VERSION}/android-studio-${ANDROID_STUDIO_VERSION}-linux.tar.gz"
  if [ -d "${HOME}/.local/lib/android-studio" ]; then
    rm -rf "${HOME}/.local/lib/android-studio"
  fi
  tar xzf "${tmp_file}" -C "${HOME}/.local/lib"
  [ -e "${HOME}/.local/share/applications/android-studio.desktop" ] && rm "${HOME}/.local/share/applications/android-studio.desktop"
  echo -e "[Desktop Entry]\nVersion=1.0\nEncoding=UTF-8\nName=Android Studio\nType=Application\nExec=${HOME}/.local/lib/android-studio/bin/studio %f\nIcon=${HOME}/.local/lib/android-studio/bin/studio.png\nComment=The official Android IDE\nCategories=Development;IDE;Programming\nTerminal=false\nStartupNotify=true\nStartupWMClass=jetbrains-studio\nMimeType=application/x-extension-iml;" > "${HOME}/.local/lib/android-studio/bin/android-studio.desktop"
  ln -sf "${HOME}/.local/lib/android-studio/bin/android-studio.desktop" "${HOME}/.local/share/applications/android-studio.desktop"
  ln -sf "${HOME}/.local/lib/android-studio/bin/studio" "${HOME}/.local/bin/studio"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/android-studio"
  chmod -R og-rwx "${HOME}/.local/lib/android-studio"
  rm "${tmp_file}"
}


#
# awscliv2 - AWS Command Line Interface
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#
install_aws_cli_v2 () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/"{bin,lib}
  chmod og-rwx "${HOME}/.local/"{bin,lib}
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  curl -sSL -o "${tmp_file}" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip -qq "${tmp_file}" -d "${tmp_dir}"
  if [ -d "${HOME}/.local/lib/aws-cli" ]; then
    rm -rf "${HOME}/.local/lib/aws-cli"
  fi
  "${tmp_dir}/aws/install" --bin-dir "${HOME}/.local/bin" --install-dir "${HOME}/.local/lib/aws-cli" --update
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/aws-cli"
  chmod -R og-rwx "${HOME}/.local/lib/aws-cli"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# Install Beyond Compare
#
install_beyond_compare () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  mkdir -p "${HOME}/.local/share/mime/packages"
  mkdir -p "${HOME}/.local/share/pixmaps"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.local/share/mime/packages" \
    "${HOME}/.local/share/pixmaps"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.local/share/mime/packages" \
    "${HOME}/.local/share/pixmaps"
  if [ -d "${HOME}/.local/lib/beyond_compare" ]; then
    rm -rf "${HOME}/.local/lib/beyond_compare"
  fi
  tmp_dir="$(mktemp --directory)"
  latest_ver="$(curl -sSf https://www.scootersoftware.com/debian/dists/bcompare5/non-free/binary-amd64/Packages \
    | grep -Pzo '(?m)Package: bcompare(\n.+)+\n\n' \
    | awk '/Version/{print $2}' \
    | sort -Vr \
    | head -1 \
    | sed -e 's/-/./g')"
  curl -sSL --output-dir "${tmp_dir}" --output "bcompare.tar.gz" "https://www.scootersoftware.com/files/bcompare-${latest_ver}.x86_64.tar.gz"
  mkdir -p "${tmp_dir}/beyond_compare" && tar xzf "${tmp_dir}/bcompare.tar.gz" -C "${tmp_dir}/beyond_compare" --strip-components=1
  mkdir -p "${HOME}/.local/lib/beyond_compare"
  "${tmp_dir}/beyond_compare/install.sh" --prefix="${HOME}/.local/lib/beyond_compare"
  cp "${tmp_dir}/beyond_compare/bcompare.png" "${HOME}/.local/lib/beyond_compare/lib64/beyondcompare/bcompare.png"
  ln -sf "${HOME}/.local/lib/beyond_compare/bin/bcompare" "${HOME}/.local/bin/bcompare"
  [ -e "${HOME}/.local/share/applications/bcompare.desktop" ] && rm "${HOME}/.local/share/applications/bcompare.desktop"
  echo -e "[Desktop Entry]\nVersion=1.0\nEncoding=UTF-8\nName=Beyond Compare\nType=Application\nExec=${HOME}/.local/lib/beyond_compare/bin/bcompare %f\nIcon=${HOME}/.local/lib/beyond_compare/lib64/beyondcompare/bcompare.png\nComment=Compare, sync, and merge files and folders\nCategories=Development;Programming\nTerminal=false\nStartupNotify=true\nMimeType=application/beyond.compare.snapshot;" > "${HOME}/.local/share/applications/bcompare.desktop"
  [ -e "${HOME}/.local/share/mime/packages/bcompare.xml" ] && rm "${HOME}/.local/share/mime/packages/bcompare.xml"
  cp "${tmp_dir}/beyond_compare/bcompare.xml" "${HOME}/.local/share/mime/packages/bcompare.xml"
  [ -e "${HOME}/.local/share/pixmaps/bcomparefull32.png" ] && rm "${HOME}/.local/share/pixmaps/bcomparefull32.png"
  cp "${tmp_dir}/beyond_compare/bcomparefull32.png" "${HOME}/.local/share/pixmaps/bcomparefull32.png"
  [ -e "${HOME}/.local/share/pixmaps/bcomparehalf32.png" ] && rm "${HOME}/.local/share/pixmaps/bcomparehalf32.png"
  cp "${tmp_dir}/beyond_compare/bcomparehalf32.png" "${HOME}/.local/share/pixmaps/bcomparehalf32.png"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/beyond_compare"
  chmod -R og-rwx "${HOME}/.local/lib/beyond_compare"
  echo "INFO: To install the file manager extension some commands need to run as root."
  SHELL=/usr/bin/bash sudo tmp_dir="${tmp_dir}" -s << 'BCOMPARE_EXT_EOF'
  [ -e "/usr/lib64/qt6/plugins/kf6/kfileitemaction/bcompare_ext_kde6.amd64.so" ] && rm "/usr/lib64/qt6/plugins/kf6/kfileitemaction/bcompare_ext_kde6.amd64.so"
  cp "${tmp_dir}/beyond_compare/ext/bcompare_ext_kde6.amd64.so" "/usr/lib64/qt6/plugins/kf6/kfileitemaction/bcompare_ext_kde6.amd64.so"
  chown root:root "/usr/lib64/qt6/plugins/kf6/kfileitemaction/bcompare_ext_kde6.amd64.so"
  chmod 0755 "/usr/lib64/qt6/plugins/kf6/kfileitemaction/bcompare_ext_kde6.amd64.so"
BCOMPARE_EXT_EOF
  rm -rf "${tmp_dir}"
}


#
# # diffoci - diff for Docker and OCI container images
# # https://github.com/reproducible-containers/diffoci
#
install_diffoci () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  latest_ver="$(curl -sSL "https://api.github.com/repos/reproducible-containers/diffoci/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"v([^"]+)".*/\1/')"
  [ -e "${HOME}/.local/bin/diffoci" ] && rm "${HOME}/.local/bin/diffoci"
  curl -sSL --output-dir "${HOME}/.local/bin" --output diffoci -L "https://github.com/reproducible-containers/diffoci/releases/download/v${latest_ver}/diffoci-v${latest_ver}.linux-amd64"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin/diffoci"
  chmod 0700 "${HOME}/.local/bin/diffoci"
}


#
# dosage - dosage is a comic strip downloader and archiver
# https://github.com/webcomics/dosage
#
install_dosage () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/lib/virtualenvs"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/lib/virtualenvs"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/lib/virtualenvs"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/virtualenvs"
  chmod og-rwx "${HOME}/.local/lib/virtualenvs"
  if [ -d "${HOME}/.local/lib/virtualenvs/dosage" ]; then
    rm -rf "${HOME}/.local/lib/virtualenvs/dosage"
  fi
  python3 -m venv --upgrade-deps "${HOME}/.local/lib/virtualenvs/dosage"
  "${HOME}/.local/lib/virtualenvs/dosage/bin/pip" install "dosage[css,bash]" --quiet
  ln -sf "${HOME}/.local/lib/virtualenvs/dosage/bin/dosage" "${HOME}/.local/bin/dosage"
  ln -sf "${HOME}/.local/lib/virtualenvs/dosage/bin/normalizer" "${HOME}/.local/bin/normalizer"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/virtualenvs/dosage"
  chmod -R og-rwx "${HOME}/.local/lib/virtualenvs/dosage"
}


#
# Install Dropbox
#
install_dropbox () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  mkdir -p "${HOME}/.config/systemd/user"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.config/systemd/user"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.config/systemd/user"
  tmp_file="$(mktemp)"
  curl -sSL -o "${tmp_file}" "https://clientupdates.dropboxstatic.com/dbx-releng/client/dropbox-lnx.x86_64-221.4.5365.tar.gz"
  if [ -d "${HOME}/.local/lib/dropbox" ]; then
    rm -rf "${HOME}/.local/lib/dropbox"
  fi
  mkdir -p "${HOME}/.local/lib/dropbox" && tar xzf "${tmp_file}" -C "${HOME}/.local/lib/dropbox" --strip-components=2
  [ -e "${HOME}/.local/lib/dropbox/dropbox.svg" ] && rm "${HOME}/.local/lib/dropbox/dropbox.svg"
  echo -e '<svg id="Layer_1" data-name="Layer 1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 235.45 200"><defs><style>.cls-1{fill:#0061ff;}</style></defs><title>DropboxGlyph</title><polygon class="cls-1" points="58.86 0 0 37.5 58.86 75 117.73 37.5 58.86 0"/><polygon class="cls-1" points="176.59 0 117.73 37.5 176.59 75 235.45 37.5 176.59 0"/><polygon class="cls-1" points="0 112.5 58.86 150 117.73 112.5 58.86 75 0 112.5"/><polygon class="cls-1" points="176.59 75 117.73 112.5 176.59 150 235.45 112.5 176.59 75"/><polygon class="cls-1" points="58.86 162.5 117.73 200 176.59 162.5 117.73 125 58.86 162.5"/></svg>' > "${HOME}/.local/lib/dropbox/dropbox.svg"
  [ -e "${HOME}/.local/share/applications/dropbox.desktop" ] && rm "${HOME}/.local/share/applications/dropbox.desktop"
  echo -e "[Desktop Entry]\nName=Dropbox\nGenericName=File Synchronizer\nComment=Sync your files across computers and to the web\nExec=${HOME}/.local/lib/dropbox/dropbox start -i\nTerminal=false\nType=Application\nIcon=${HOME}/.local/lib/dropbox/dropbox.svg\nCategories=Network;FileTransfer;\nKeywords=file;synchronization;sharing;collaboration;cloud;storage;backup;\nStartupNotify=false\nX-GNOME-Autostart-Delay=10" > "${HOME}/.local/share/applications/dropbox.desktop"
  ln -sf "${HOME}/.local/lib/dropbox/dropbox" "${HOME}/.local/bin/dropbox"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/dropbox"
  chmod -R og-rwx "${HOME}/.local/lib/dropbox"
  rm "${tmp_file}"
}


#
# gcloud CLI - Google Cloud Command Line Interface
# https://cloud.google.com/sdk/docs/install
#
install_google_cloud_cli () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/"{bin,lib}
  chmod og-rwx "${HOME}/.local/"{bin,lib}
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  curl -sSL -o "${tmp_file}" "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz"
  if [ -d "${HOME}/.local/lib/google-cloud-sdk" ]; then
    rm -rf "${HOME}/.local/lib/google-cloud-sdk"
  fi
  tar xzf "${tmp_file}" -C "${HOME}/.local/lib"
  "${HOME}/.local/lib/google-cloud-sdk/install.sh" --quiet --usage-reporting false --command-completion true --path-update true --additional-components cloud-sql-proxy docker-credential-gcr gke-gcloud-auth-plugin istioctl log-streaming
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/google-cloud-sdk"
  chmod -R og-rwx "${HOME}/.local/lib/google-cloud-sdk"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# Heroic - Games launcher
# https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/
#
install_heroic () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  latest_ver=$(curl -sL "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"v([^"]+)".*/\1/')
  if [ -d "${HOME}/.local/lib/heroic" ]; then
    rm -rf "${HOME}/.local/lib/heroic"
  fi
  mkdir -p "${HOME}/.local/lib/heroic"
  curl -sSL --output-dir "${HOME}/.local/lib/heroic" --output "Heroic-${latest_ver}-linux-x86_64.AppImage" "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${latest_ver}/Heroic-${latest_ver}-linux-x86_64.AppImage"
  curl -sSL --output-dir "${HOME}/.local/lib/heroic" --output "heroic.png" "https://raw.githubusercontent.com/Heroic-Games-Launcher/HeroicGamesLauncher/main/public/icon.png"
  chmod 0700 "${HOME}/.local/lib/heroic/Heroic-${latest_ver}-linux-x86_64.AppImage"
  echo -e "[Desktop Entry]\nName=Heroic Games Launcher\nComment=Open Source GOG and Epic Games launcher\nExec=${HOME}/.local/lib/heroic/Heroic-${latest_ver}-linux-x86_64.AppImage %U\nIcon=${HOME}/.local/lib/heroic/heroic.png\nType=Application\nStartupNotify=true\nCategories=Game;\nStartupWMClass=Heroic\nMimeType=x-scheme-handler/heroic;" > "${HOME}/.local/lib/heroic/heroic.desktop"
  ln -sf "${HOME}/.local/lib/heroic/Heroic-${latest_ver}-linux-x86_64.AppImage" "${HOME}/.local/bin/heroic"
  ln -sf "${HOME}/.local/lib/heroic/heroic.desktop" "${HOME}/.local/share/applications/heroic.desktop"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/heroic" "${HOME}/.local/bin/heroic" "${HOME}/.local/share/applications/heroic.desktop"
  chmod -R og-rwx "${HOME}/.local/lib/heroic"
}


#
# JetBrains IDEs
#
install_jetbrains_ide () {

  # CODE | JETBRAINS IDE
  # --------------------------------------
  # CL   | CLion
  # DG   | DataGrip
  # GO   | GoLand
  # IIC  | IntelliJ IDEA Community Edition
  # IIU  | IntelliJ IDEA Ultimate Edition
  # PCC  | PyCharm Community Edition
  # PCP  | PyCharm Professional Edition
  # PS   | PhpStorm
  # RD   | Rider
  # RM   | RubyMine
  # RR   | RustRover
  # WS   | WebStorm
  #
  # Source: https://data.services.jetbrains.com/products
  code="$1"
  case "$code" in
    "CL" )
      ide="clion";
      name="CLion";
      desc="A cross-platform IDE for C and C++";
      ;;
    "DG" )
      ide="datagrip";
      name="DataGrip";
      desc="A cross-platform IDE for many databases";
      ;;
    "GO" )
      ide="goland";
      name="GoLand";
      desc="A cross-platform IDE for Go";
      ;;

    "IIC" )
      ide="idea";
      name="IntelliJ IDEA";
      desc="A cross-platform IDE for Java";
      ;;
    "IIU" )
      ide="idea";
      name="IntelliJ IDEA";
      desc="A cross-platform IDE for Java";
      ;;
    "PCC" )
      ide="pycharm";
      name="PyCharm";
      desc="A cross-platform IDE for Python";
      ;;
    "PCP" )
      ide="pycharm";
      name="PyCharm";
      desc="A cross-platform IDE for Python";
      ;;
    "PS" )
      ide="phpstorm";
      name="PhpStorm";
      desc="A cross-platform IDE for PHP";
      ;;
    "RD" )
      ide="rider";
      name="Rider";
      desc="A cross-platform IDE for .NET";
      ;;
    "RM" )
      ide="rubymine";
      name="RubyMine";
      desc="A cross-platform IDE for Ruby";
      ;;
    "RR" )
      ide="rustrover";
      name="RustRover";
      desc="A powerful IDE for Rust";
      ;;
    "WS" )
      ide="webstorm";
      name="WebStorm";
      desc="A cross-platform IDE for Javascript";
      ;;
    * )
      echo "ERROR: Invalid option specified.";
      return 1
      ;;
  esac

  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"

  # Prepend base URL for download
  url="https://data.services.jetbrains.com/products/download?platform=linux&code=$code"

  # Get location header for file URL
  headers=$(wget -qS --max-redirect 0 --spider "$url" 2>&1 || true)
  location=$(echo "$headers" | tac | grep -m 1 "Location: ")
  file_url=$(echo "$location" | sed 's/.*Location: //')

  # Set install directory
  install_dir="${HOME}/.local/lib/$ide"

  # Set download directory
  tmp_file=$(mktemp)

  # Download installation archive
  wget -q -cO "${tmp_file}" "${file_url}" --read-timeout=5 --tries=0

  if [ -d "$install_dir" ]; then
    # Remove existing installation directory if it exists
    rm -rf "${install_dir}"
  fi

  # Extract archive
  if mkdir -p "${install_dir}"; then
    tar -xzf "${tmp_file}" -C "${install_dir}" --strip-components=1
    chown -R "$(id -un)":"$(id -gn)" "${install_dir}"
    chmod -R og-rwx "${install_dir}"
  fi

  # Setup desktop shortcut in /usr/local/share/applications
  bin="${install_dir}/bin"
  desktop_shortcut="${HOME}/.local/share/applications/${ide}.desktop"
  [ -e "${desktop_shortcut}" ] && rm "${desktop_shortcut}"
  echo -e "[Desktop Entry]\nVersion=1.0\nEncoding=UTF-8\nName=${name}\nType=Application\nCategories=Development;Programming\nTerminal=false\nStartupNotify=true\nComment=${desc}\nExec=\"${bin}/${ide}\" %U\nIcon=${bin}/${ide}.png" > "${desktop_shortcut}"

  # Setup symlink in /usr/local/bin
  target="${bin}/${ide}"
  ln -sf "${target}" "${HOME}/.local/bin/${ide}"

  # Clean up
  rm "${tmp_file}"

  return 0
}


#
# KeyStore Explorer - GUI replacement for the Java command-line utilities
#                     keytool and jarsigner
# https://github.com/kaikramer/keystore-explorer
#
install_keystore_explorer () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  latest_ver=$(curl -sL "https://api.github.com/repos/kaikramer/keystore-explorer/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/')
  file_ver=$(echo "${latest_ver}" \
    | sed -E 's/^v//' \
    | sed -E 's/[\.]//g')
  curl -sSL -o "${tmp_file}" "https://github.com/kaikramer/keystore-explorer/releases/download/${latest_ver}/kse-${file_ver}.zip"
  unzip -qq "${tmp_file}" -d "${tmp_dir}"
  if [ -d "${HOME}/.local/lib/kse" ]; then
    rm -rf "${HOME}/.local/lib/kse"
  fi
  mkdir -p "${HOME}/.local/lib/kse"
  mv "${tmp_dir}/kse-${file_ver}/"* "${HOME}/.local/lib/kse"
  chmod 0700 "${HOME}/.local/lib/kse/kse.sh"
  [ -e "${HOME}/.local/bin/kse" ] && rm "${HOME}/.local/bin/kse"
  ln -s "${HOME}/.local/lib/kse/kse.sh" "${HOME}/.local/bin/kse"
  echo -e "[Desktop Entry]\nName=KeyStore Explorer\nGenericName=Multipurpose keystore and certificate tool\nComment=User friendly GUI application for creating, managing and examining keystores, keys, certificates, certificate requests, certificate revocation lists and more.\nExec=${HOME}/.local/lib/kse/kse.sh %f\nTryExec=${HOME}/.local/lib/kse/kse.sh\nTerminal=false\nType=Application\nIcon=${HOME}/.local/lib/kse/icons/kse_512.png\nCategories=Utility;Security;System;Java;\nMimeType=application/x-pkcs12;application/x-java-keystore;application/x-java-jce-keystore;application/pkcs10;application/pkix-pkipath;application/pkix-cert;application/pkix-crl;application/x-x509-ca-cert;application/x-pkcs7-certificates;" > "${HOME}/.local/lib/kse/kse.desktop"
  ln -sf "${HOME}/.local/lib/kse/kse.desktop" "${HOME}/.local/share/applications/kse.desktop"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/kse" "${HOME}/.local/bin/kse" "${HOME}/.local/share/applications/kse.desktop"
  chmod -R og-rwx "${HOME}/.local/lib/kse"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# kubeswitch - Kubernetes context switcher
# https://github.com/danielfoehrKn/kubeswitch
#
install_kubeswitch () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  latest_ver=$(curl -sL "https://api.github.com/repos/danielfoehrKn/kubeswitch/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/')
  [ -e "${HOME}/.local/bin/kubeswitch" ] && rm "${HOME}/.local/bin/kubeswitch"
  curl -sSL --output-dir "${HOME}/.local/bin" --output kubeswitch -L "https://github.com/danielfoehrKn/kubeswitch/releases/download/${latest_ver}/switcher_linux_amd64"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin/kubeswitch"
  chmod 0700 "${HOME}/.local/bin/kubeswitch"
  grep -qxF 'source <(kubeswitch init bash)' "${HOME}/.bashrc" || echo 'source <(kubeswitch init bash)' >> "${HOME}/.bashrc"
}


#
# Obsidian - Markdown editor
# https://github.com/obsidianmd
#
install_obsidian () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  latest_ver=$(curl -sL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"v([^"]+)".*/\1/')
  if [ -d "${HOME}/.local/lib/obsidian" ]; then
    rm -rf "${HOME}/.local/lib/obsidian"
  fi
  mkdir -p "${HOME}/.local/lib/obsidian"
  curl -sSL --output-dir "${HOME}/.local/lib/obsidian" --output "Obsidian-${latest_ver}.AppImage" "https://github.com/obsidianmd/obsidian-releases/releases/download/v${latest_ver}/Obsidian-${latest_ver}.AppImage"
  curl -sSL --output-dir "${HOME}/.local/lib/obsidian" --output "obsidian.png" "https://avatars.githubusercontent.com/u/65011256"
  chmod 0700 "${HOME}/.local/lib/obsidian/Obsidian-${latest_ver}.AppImage"
  echo -e "[Desktop Entry]\nName=Obsidian\nGenericName=Markdown Editor\nExec=${HOME}/.local/lib/obsidian/Obsidian-${latest_ver}.AppImage %U\nIcon=${HOME}/.local/lib/obsidian/obsidian.png\nType=Application\nStartupNotify=true\nCategories=Office;Education;Science;\nMimeType=text/markdown;" > "${HOME}/.local/lib/obsidian/obsidian.desktop"
  ln -sf "${HOME}/.local/lib/obsidian/Obsidian-${latest_ver}.AppImage" "${HOME}/.local/bin/obsidian"
  ln -sf "${HOME}/.local/lib/obsidian/obsidian.desktop" "${HOME}/.local/share/applications/obsidian.desktop"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/obsidian" "${HOME}/.local/bin/obsidian" "${HOME}/.local/share/applications/obsidian.desktop"
  chmod -R og-rwx "${HOME}/.local/lib/obsidian"
}


#
# shellcheck - Static analysis tool for shell scripts 
# https://github.com/koalaman/shellcheck
#
install_shellcheck () {
  mkdir -p "${HOME}/.local/bin"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin"
  chmod og-rwx "${HOME}/.local/bin"
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  latest_ver=$(curl -sL "https://api.github.com/repos/koalaman/shellcheck/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/')

  curl -sSL -o "${tmp_file}" "https://github.com/koalaman/shellcheck/releases/download/${latest_ver}/shellcheck-${latest_ver}.linux.x86_64.tar.xz"
  tar -xJf "${tmp_file}" -C "${tmp_dir}"
  [ -e "${HOME}/.local/bin/shellcheck" ] && rm "${HOME}/.local/bin/shellcheck"
  mv "${tmp_dir}/shellcheck-${latest_ver}/shellcheck" "${HOME}/.local/bin/shellcheck"
  chown "$(id -un)":"$(id -gn)" "${HOME}/.local/bin/shellcheck"
  chmod 0700 "${HOME}/.local/bin/shellcheck"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# Install Slack
#
install_slack () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  latest_ver="$(curl -sSLf "https://packagecloud.io/slacktechnologies/slack/debian/dists/jessie/main/binary-amd64/Packages" \
    | grep -Pzo '(?m)Package: slack-desktop(\n.+)+\n\n' \
    | awk '/Version/{print $2}' \
    | sort -Vr \
    | head -1)"
  curl -sSL -o "${tmp_file}" "https://downloads.slack-edge.com/desktop-releases/linux/x64/${latest_ver}/slack-desktop-${latest_ver}-amd64.deb"
  ar x --output "${tmp_dir}" "${tmp_file}" "data.tar.xz"
  tar -xJf "${tmp_dir}/data.tar.xz" -C "${tmp_dir}"
  if [ -d "${HOME}/.local/lib/slack" ]; then
    rm -rf "${HOME}/.local/lib/slack"
  fi
  mv "${tmp_dir}/usr" "${HOME}/.local/lib/slack"
  sed -i \
    -e "s#Exec=/usr/bin/slack#Exec=${HOME}/.local/lib/slack/bin/slack#g" \
    -e "s#Icon=/usr/share/pixmaps/slack.png#Icon=${HOME}/.local/lib/slack/share/pixmaps/slack.png#g" \
    "${HOME}/.local/lib/slack/share/applications/slack.desktop"
  ln -sf "${HOME}/.local/lib/slack/bin/slack" "${HOME}/.local/bin/slack"
  ln -sf "${HOME}/.local/lib/slack/share/applications/slack.desktop" "${HOME}/.local/share/applications/slack.desktop"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/slack"
  chmod -R og-rwx "${HOME}/.local/lib/slack"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# Install SmartGit
#
install_smartgit () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  tmp_file="$(mktemp)"
  curl -sSL -o "${tmp_file}" "https://downloads.syntevo.com/downloads/smartgit/smartgit-linux-${SMARTGIT_VERSION}.tar.gz"
  if [ -d "${HOME}/.local/lib/smartgit" ]; then
    rm -rf "${HOME}/.local/lib/smartgit"
  fi
  tar xzf "${tmp_file}" -C "${HOME}/.local/lib"
  [ -e "${HOME}/.local/share/applications/syntevo-smartgit.desktop" ] && rm "${HOME}/.local/share/applications/syntevo-smartgit.desktop"
  "${HOME}/.local/lib/smartgit/bin/add-menuitem.sh"
  [ -e "/usr/share/hunspell/en_GB-large.aff" ] && cp -f "/usr/share/hunspell/en_GB-large.aff" "${HOME}/.local/lib/smartgit/dictionaries/en_GB-large.aff"
  [ -e "/usr/share/hunspell/en_GB-large.dic" ] && cp -f "/usr/share/hunspell/en_GB-large.dic" "${HOME}/.local/lib/smartgit/dictionaries/en_GB-large.dic"
  ln -sf "${HOME}/.local/lib/smartgit/bin/smartgit.sh" "${HOME}/.local/bin/smartgit"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/smartgit"
  chmod -R og-rwx "${HOME}/.local/lib/smartgit"
  rm "${tmp_file}"
}


#
# Install Sublime Text
#
install_sublimetext () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications"
  tmp_file="$(mktemp)"
  latest_ver="$(curl -sSf "https://download.sublimetext.com/apt/stable/Packages" \
    | grep -Pzo '(?m)Package: sublime-text(\n.+)+\n\n' \
    | awk '/Version/{print $2}' \
    | sort -Vr \
    | head -1)"
  curl -sSL -o "${tmp_file}" "https://download.sublimetext.com/sublime_text_build_${latest_ver}_x64.tar.xz"
  if [ -d "${HOME}/.local/lib/sublime_text" ]; then
    rm -rf "${HOME}/.local/lib/sublime_text"
  fi
  tar xJf "${tmp_file}" -C "${HOME}/.local/lib"
  sed -i \
    -e "s#/opt/#${HOME}/.local/lib/#g" \
    -e "s#Icon=sublime-text#Icon=${HOME}/.local/lib/sublime_text/Icon/256x256/sublime-text.png#g" \
    "${HOME}/.local/lib/sublime_text/sublime_text.desktop"
  ln -sf "${HOME}/.local/lib/sublime_text/sublime_text.desktop" "${HOME}/.local/share/applications/sublime_text.desktop"
  ln -sf "${HOME}/.local/lib/sublime_text/sublime_text" "${HOME}/.local/bin/sublime_text"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/sublime_text"
  chmod -R og-rwx "${HOME}/.local/lib/sublime_text"
  rm "${tmp_file}"
}


#
# Install Tide Prompt for Fish Shell
#
install_tide () {
  /usr/bin/fish -c "
    if test -f '/home/jc/.config/fish/functions/tide.fish'

      # Update Tide prompt for Fish Shell
      fisher update ilancosman/tide@v6

    else

      # Install Tide prompt for Fish Shell
      fisher install ilancosman/tide@v6

      # Configure tide
      tide configure --auto --style=Rainbow --prompt_colors='True color' \
        --show_time='24-hour format' --rainbow_prompt_separators=Round \
        --powerline_prompt_heads=Round --powerline_prompt_tails=Round \
        --powerline_prompt_style='Two lines, character' \
        --prompt_connection=Solid --powerline_right_prompt_frame=No \
        --prompt_connection_andor_frame_color=Darkest --prompt_spacing=Compact \
        --icons='Many icons' --transient=Yes

    end
  "
}


#
# Install Visual Studio Code
#
install_vscode () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/share/applications"
  mkdir -p "${HOME}/.local/share/mime/packages"
  mkdir -p "${HOME}/.local/share/bash-completion/completions"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.local/share/mime" \
    "${HOME}/.local/share/mime/packages" \
    "${HOME}/.local/share/bash-completion" \
    "${HOME}/.local/share/bash-completion/completions"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/share" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.local/share/mime" \
    "${HOME}/.local/share/mime/packages" \
    "${HOME}/.local/share/bash-completion" \
    "${HOME}/.local/share/bash-completion/completions"
  tmp_file="$(mktemp)"
  tmp_dir="$(mktemp --directory)"
  curl -sSL -o "${tmp_file}" "https://update.code.visualstudio.com/latest/linux-deb-x64/stable"
  ar x --output "${tmp_dir}" "${tmp_file}" "data.tar.xz"
  tar -xJf "${tmp_dir}/data.tar.xz" -C "${tmp_dir}"
  if [ -d "${HOME}/.local/lib/vscode" ]; then
    rm -rf "${HOME}/.local/lib/vscode"
  fi
  mv "${tmp_dir}/usr/share/code" "${HOME}/.local/lib/vscode"
  mv "${tmp_dir}/usr/share/"* "${HOME}/.local/lib/vscode/"
  [ -e "${HOME}/.local/share/mime/packages/code-workspace.xml" ] && rm "${HOME}/.local/share/mime/packages/code-workspace.xml"
  ln -sf "${HOME}/.local/lib/vscode/mime/packages/code-workspace.xml" "${HOME}/.local/share/mime/packages/code-workspace.xml"
  [ -e "${HOME}/.local/share/bash-completion/completions/code" ] && rm "${HOME}/.local/share/bash-completion/completions/code"
  ln -sf "${HOME}/.local/lib/vscode/bash-completion/completions/code" "${HOME}/.local/share/bash-completion/completions/code"
  sed -i \
    -e "s#Exec=/usr/share/code/code#Exec=${HOME}/.local/lib/vscode/code#g" \
    -e "s#Icon=vscode#Icon=${HOME}/.local/lib/vscode/pixmaps/vscode.png#g" \
    "${HOME}/.local/lib/vscode/applications/code-url-handler.desktop" \
    "${HOME}/.local/lib/vscode/applications/code.desktop"
  ln -sf "${HOME}/.local/lib/vscode/bin/code" "${HOME}/.local/bin/code"
  ln -sf "${HOME}/.local/lib/vscode/applications/code.desktop" "${HOME}/.local/share/applications/code.desktop"
  ln -sf "${HOME}/.local/lib/vscode/applications/code-url-handler.desktop" "${HOME}/.local/share/applications/code-url-handler.desktop"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/vscode"
  chmod -R og-rwx "${HOME}/.local/lib/vscode"
  rm -rf "${tmp_file}" "${tmp_dir}"
}


#
# yamlpath - YAML/JSON/EYAML/Compatible get/set/merge/validate/scan/convert/
# diff processors using powerful, intuitive, command-line friendly syntax.
# https://github.com/wwkimball/yamlpath
#
install_yamlpath () {
  mkdir -p "${HOME}/.local/"{bin,lib}
  mkdir -p "${HOME}/.local/lib/virtualenvs"
  chown "$(id -un)":"$(id -gn)" \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/lib/virtualenvs"
  chmod og-rwx \
    "${HOME}/.local/"{bin,lib} \
    "${HOME}/.local/lib/virtualenvs"
  if [ -d "${HOME}/.local/lib/virtualenvs/yamlpath" ]; then
    rm -rf "${HOME}/.local/lib/virtualenvs/yamlpath"
  fi
  python3 -m venv --upgrade-deps "${HOME}/.local/lib/virtualenvs/yamlpath"
  "${HOME}/.local/lib/virtualenvs/yamlpath/bin/pip" install "yamlpath" --quiet
  ln -sf "${HOME}/.local/lib/virtualenvs/yamlpath/bin/"yaml-* "${HOME}/.local/bin"
  chown -R "$(id -un)":"$(id -gn)" "${HOME}/.local/lib/virtualenvs/yamlpath"
  chmod -R og-rwx "${HOME}/.local/lib/virtualenvs/yamlpath"
}


#-------------------------------------------------------------------------------


CHOICES=$(whiptail \
          --notags \
          --separate-output \
          --title "3rd Party Software Installation" \
          --checklist "Choose what 3rd party software to install" \
          22 77 15 \
          "AWS_CLI_V2" "AWS CLI V2 (Latest version)" ON \
          "DIFFOCI" "DiffOCI (Latest version)" ON \
          "DOSAGE" "Dosage (Latest version)" ON \
          "DROPBOX" "Dropbox (v221.4.5365 - it auto updates itself)" OFF \
          "ANDROID_STUDIO" "Google Android Studio (v${ANDROID_STUDIO_VERSION})" ON \
          "GOOGLE_CLOUD_CLI" "Google Cloud CLI (Latest version)" ON \
          "HEROIC" "Heroic Games Launcher (Latest version)" ON \
          "CLION" "JetBrains CLion (Latest version)" OFF \
          "DATAGRIP" "JetBrains DataGrip (Latest version)" OFF \
          "GOLAND" "JetBrains GoLand (Latest version)" OFF \
          "INTELLIJ_IDEA" "JetBrains IntelliJ IDEA Ultimate Edition (Latest version)" OFF \
          "PHPSTORM" "JetBrains PhpStorm (Latest version)" OFF \
          "PYCHARM_PRO" "JetBrains PyCharm Professional (Latest version)" OFF \
          "RIDER" "JetBrains Rider (Latest version)" OFF \
          "RUBYMINE" "JetBrains RubyMine (Latest version)" OFF \
          "RUSTROVER" "JetBrains RustRover (Latest version)" OFF \
          "WEBSTORM" "JetBrains WebStorm (Latest version)" OFF \
          "KEYSTORE_EXPLORER" "Keystore Explorer (Latest version)" ON \
          "KUBESWITCH" "Kubeswitch (Latest version)" ON \
          "VSCODE" "Microsoft Visual Studio Code (Latest version)" ON \
          "OBSIDIAN" "Obsidian (Latest version)" ON \
          "BEYOND_COMPARE" "Scooter Beyond Compare (Latest version)" ON \
          "SHELLCHECK" "ShellCheck (Latest version)" ON \
          "SLACK" "Slack (Latest version)" ON \
          "SUBLIME_TEXT" "Sublime Text (Latest version)" ON \
          "SMARTGIT" "Syntevo SmartGit (v${SMARTGIT_VERSION})" ON \
          "TIDE" "Tide prompt for Fish Shell (Latest version)" ON \
          "YAMLPATH" "YAMLPath (Latest version)" ON \
          3>&1 1>&2 2>&3)

if [ -z "$CHOICES" ]; then
  echo "No option was selected (user hit Cancel or unselected all options)"
else
  for CHOICE in $CHOICES; do
    case "$CHOICE" in
    "ANDROID_STUDIO")
      echo "Installing Android Studio"
      install_android_studio
      ;;
    "AWS_CLI_V2")
      echo "Installing AWS CLI V2"
      install_aws_cli_v2
      ;;
    "BEYOND_COMPARE")
      echo "Installing Beyond Compare"
      install_beyond_compare
      ;;
    "CLION")
      echo "Installing CLion"
      install_jetbrains_ide "CL"
      ;;
    "DATAGRIP")
      echo "Installing DataGrip"
      install_jetbrains_ide "DG"
      ;;
    "DIFFOCI")
      echo "Installing DiffOCI"
      install_diffoci
      ;;
    "DOSAGE")
      echo "Installing Dosage"
      install_dosage
      ;;
    "DROPBOX")
      echo "Installing Dropbox"
      install_dropbox
      ;;
    "GOLAND")
      echo "Installing GoLand"
      install_jetbrains_ide "GO"
      ;;
    "GOOGLE_CLOUD_CLI")
      echo "Installing Google Cloud CLI"
      install_google_cloud_cli
      ;;
    "HEROIC")
      echo "Installing Heroic Games Launcher"
      install_heroic
      ;;
    "INTELLIJ_IDEA")
      echo "Installing IntelliJ IDEA Ultimate Edition"
      install_jetbrains_ide "IIU"
      ;;
    "KEYSTORE_EXPLORER")
      echo "Installing Keystore Explorer"
      install_keystore_explorer
      ;;
    "KUBESWITCH")
      echo "Installing Kubeswitch"
      install_kubeswitch
      ;;
    "OBSIDIAN")
      echo "Installing Obsidian"
      install_obsidian
      ;;
    "PHPSTORM")
      echo "Installing PhpStorm"
      install_jetbrains_ide "PS"
      ;;
    "PYCHARM_PRO")
      echo "Installing PyCharm Professional"
      install_jetbrains_ide "PCP"
      ;;
    "RIDER")
      echo "Installing Rider"
      install_jetbrains_ide "RD"
      ;;
    "RUBYMINE")
      echo "Installing RubyMine"
      install_jetbrains_ide "RM"
      ;;
    "RUSTROVER")
      echo "Installing RustRover"
      install_jetbrains_ide "RR"
      ;;
    "SHELLCHECK")
      echo "Installing ShellCheck"
      install_shellcheck
      ;;
    "SLACK")
      echo "Installing Slack"
      install_slack
      ;;
    "SMARTGIT")
      echo "Installing SmartGit"
      install_smartgit
      ;;
    "SUBLIME_TEXT")
      echo "Installing Sublime Text"
      install_sublimetext
      ;;
    "TIDE")
      echo "Installing Tide prompt for Fish Shell"
      install_tide
      ;;
    "VSCODE")
      echo "Installing Visual Studio Code"
      install_vscode
      ;;
    "WEBSTORM")
      echo "Installing WebStorm"
      install_jetbrains_ide "WS"
      ;;
    "YAMLPATH")
      echo "Installing YAMLPath"
      install_yamlpath
      ;;
    *)
      echo "Unsupported item $CHOICE!" >&2
      exit 1
      ;;
    esac
  done
fi

[ -e "${HOME}/.local/share/applications" ] && update-desktop-database "${HOME}/.local/share/applications"
[ -e "${HOME}/.local/share/mime" ] && update-mime-database "${HOME}/.local/share/mime"
