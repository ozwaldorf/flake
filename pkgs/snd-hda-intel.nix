{
  pkgs,
  lib,
  kernel ? pkgs.linuxPackages_6_12.kernel,
  patches ? [ ],
}:

# Build an in-tree kernel module (based of amdgpu)
pkgs.stdenv.mkDerivation {
  inherit patches;
  pname = "snd-hda-intel";
  modulePath = "sound/pci/hda";

  inherit (kernel)
    src
    version
    postPatch
    nativeBuildInputs
    ;
  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;
  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build
    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux          .
    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';
  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
  '';
  meta = {
    description = "snd-hda-intel standalone kernel module with patches exposed";
    license = lib.licenses.gpl3;
  };
}
