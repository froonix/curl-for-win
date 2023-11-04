#!/usr/bin/env bash

# Copyright (C) Viktor Szakats. See LICENSE.md
# SPDX-License-Identifier: MIT

# shellcheck disable=SC3040,SC2039
set -o xtrace -o errexit -o nounset; [ -n "${BASH:-}${ZSH_NAME:-}" ] && set -o pipefail

export _NAM _VER _OUT _BAS _DST

_NAM="$(basename "$0" | cut -f 1 -d '.' | sed 's/-autotools//')"
_VER="$1"

(
  cd "${_NAM}"  # mandatory component

  cache='configure-cache.txt'
  rm -f "${cache}"

  rm -r -f "${_PKGDIR:?}" "${_BLDDIR:?}-shared" "${_BLDDIR:?}-static"

  [ -f 'configure' ] || autoreconf --force --install

  [ "${CW_DEV_CROSSMAKE_REPRO:-}" = '1' ] && export AR="${AR_NORMALIZE}"

  # tell libtool to allow building a shared library against static libs
  export lt_cv_deplibs_check_method='pass_all'

  for pass in shared static; do

    options="${_CONFIGURE_GLOBAL}"
    export CC="${_CC_GLOBAL}"
    export CFLAGS="${_CFLAGS_GLOBAL} -O3"
    export CPPFLAGS="${_CPPFLAGS_GLOBAL}"
    export RCFLAGS="${_RCFLAGS_GLOBAL}"
    export LDFLAGS="${_LDFLAGS_GLOBAL} ${_LDFLAGS_GLOBAL_AUTOTOOLS}"
    export LIBS="${_LIBS_GLOBAL}"

    [ "${_CONFIG#*main*}" = "${_CONFIG}" ] && LDFLAGS+=' -v'

    options+=' --enable-unix-sockets'

    if [ ! "${_CONFIG#*werror*}" = "${_CONFIG}" ]; then
      options+=' --enable-werror'
    fi

    if [ ! "${_CONFIG#*debug*}" = "${_CONFIG}" ]; then
      options+=' --enable-debug'
    else
      options+=' --disable-debug'
      CPPFLAGS+=' -DNDEBUG'
    fi

    if [ "${CW_DEV_LLD_REPRODUCE:-}" = '1' ] && [ "${_LD}" = 'lld' ]; then
      if [ "${pass}" = 'shared' ]; then
        LDFLAGS+=" -Wl,--reproduce=$(pwd)/$(basename "$0" .sh)-dyn.tar"
      else
        LDFLAGS+=" -Wl,--reproduce=$(pwd)/$(basename "$0" .sh)-bin.tar"
      fi
    fi

    if [ "${pass}" = 'static' ]; then
      LDFLAGS+=" ${_LDFLAGS_BIN_GLOBAL}"
    fi

    if [ "${_OS}" = 'win' ] && [ "${_CONFIG#*unicode*}" != "${_CONFIG}" ]; then
      CPPFLAGS+=' -Dmain=wmain'  # FIXME: upstream. https://github.com/curl/curl/issues/7229
      CPPFLAGS+=' -DUNICODE -D_UNICODE'
      LDFLAGS+=' -municode'
    fi

    if [ "${CW_MAP}" = '1' ]; then
      if [ "${pass}" = 'shared' ]; then
        _MAP_NAME="libcurl${_CURL_DLL_SUFFIX}.map"
      else
        _MAP_NAME='curl.map'
      fi
      if [ "${_OS}" = 'mac' ]; then
        LDFLAGS+=" -Wl,-map,${_MAP_NAME}"
      else
        LDFLAGS+=" -Wl,-Map,${_MAP_NAME}"
      fi
    fi

    if [ ! "${_CONFIG#*bldtst*}" = "${_CONFIG}" ] || \
       [ ! "${_CONFIG#*pico*}" = "${_CONFIG}" ] || \
       [ ! "${_CONFIG#*nano*}" = "${_CONFIG}" ]; then
      options+=' --disable-alt-svc'
    else
      options+=' --enable-alt-svc'
    fi

    if [ ! "${_CONFIG#*bldtst*}" = "${_CONFIG}" ] || \
       [ ! "${_CONFIG#*pico*}" = "${_CONFIG}" ]; then
      options+=' --disable-basic-auth --disable-bearer-auth --disable-digest-auth --disable-kerberos-auth --disable-negotiate-auth --disable-aws'
      options+=' --disable-dict --disable-file --disable-gopher --disable-mqtt --disable-rtsp --disable-smb --disable-telnet --disable-tftp'
      options+=' --disable-ftp'
      options+=' --disable-imap --disable-pop3 --disable-smtp'
      options+=' --disable-ldap --disable-ldaps'
    else
      options+=' --enable-dict --enable-file --enable-gopher --enable-mqtt --enable-rtsp --enable-smb --enable-telnet --enable-tftp'
      if [ "${_CONFIG#*noftp*}" = "${_CONFIG}" ]; then
        options+=' --enable-ftp'
      else
        options+=' --disable-ftp'
      fi
      options+=' --enable-imap --enable-pop3 --enable-smtp'
      if [ "${_OS}" = 'win' ]; then
        options+=' --enable-ldap --enable-ldaps --with-ldap-lib=wldap32'
      elif [ "${_OS}" != 'mac' ] || [ "${_OSVER}" -ge '1010' ]; then  # On macOS we use the built-in LDAP lib
        options+=' --disable-ldap --disable-ldaps'
      fi
    fi

    # NOTE: root path with spaces breaks all values with '${_TOP}'. But,
    #       autotools breaks on spaces anyway, so we leave it like that.

    if [ -n "${_ZLIB}" ]; then
      options+=" --with-zlib=${_TOP}/${_ZLIB}/${_PP}"
    else
      options+=' --without-zlib'
    fi

    if [ -d ../brotli ] && [ "${_CONFIG#*nobrotli*}" = "${_CONFIG}" ]; then
      options+=" --with-brotli=${_TOP}/brotli/${_PP}"
      LDFLAGS+=" -L${_TOP}/brotli/${_PP}/lib"
      LIBS+=' -lbrotlicommon'
    else
      options+=' --without-brotli'
    fi
    if [ -d ../zstd ] && [ "${_CONFIG#*nozstd*}" = "${_CONFIG}" ]; then
      options+=" --with-zstd=${_TOP}/zstd/${_PP}"
      LDFLAGS+=" -L${_TOP}/zstd/${_PP}/lib"
      LIBS+=' -lzstd'
    else
      options+=' --without-zstd'
    fi

    h3=0

    mainssl=''  # openssl, wolfssl, mbedtls, schannel, secure-transport, gnutls, bearssl, rustls

    if [ -n "${_OPENSSL}" ]; then
      [ -n "${mainssl}" ] || mainssl='openssl'
      options+=" --with-openssl=${_TOP}/${_OPENSSL}/${_PP}"
      options+=' --disable-openssl-auto-load-config'
      if [ "${_OPENSSL}" = 'boringssl' ] || [ "${_OPENSSL}" = 'awslc' ]; then
        if [ "${_OPENSSL}" = 'boringssl' ]; then
          CPPFLAGS+=" -DCURL_BORINGSSL_VERSION=\\\"$(printf '%.8s' "${BORINGSSL_VER_}")\\\""
        fi
        if [ "${_TOOLCHAIN}" = 'mingw-w64' ] && [ "${_CPU}" = 'x64' ] && [ "${_CRT}" = 'ucrt' ]; then  # FIXME
          LDFLAGS+=' -Wl,-Bdynamic,-lpthread,-Bstatic'
        else
          LDFLAGS+=' -Wl,-Bstatic,-lpthread,-Bdynamic'
        fi
        h3=1
      elif [ "${_OPENSSL}" = 'quictls' ] || [ "${_OPENSSL}" = 'libressl' ] || [ "${_OPENSSL}" = 'openssl' ]; then
        if [ "${_OS}" = 'win' ]; then
          if [ "${_OPENSSL}" = 'libressl' ]; then
            CPPFLAGS+=' -DLIBRESSL_DISABLE_OVERRIDE_WINCRYPT_DEFINES_WARNING'
            if [ "${CURL_VER_}" = '8.4.0' ]; then
              # Workaround for accidentally detecting 'arc4random' inside LibreSSL (as of
              # v3.8.2) then failing to use it due to missing the necessary LibreSSL header,
              # then using a non-C89 type in curl's local replacement declaration:
              #   ../../lib/rand.c:37:1: error: unknown type name 'uint32_t'
              #      37 | uint32_t arc4random(void);
              #         | ^
              export ac_cv_func_arc4random='no'
            fi
          fi
          LIBS+=' -lbcrypt'  # for auto-detection
        fi
        [ "${_OPENSSL}" = 'openssl' ] || h3=1
      fi
    fi

    if [ -d ../wolfssl ]; then
      [ -n "${mainssl}" ] || mainssl='wolfssl'
      options+=" --with-wolfssl=${_TOP}/wolfssl/${_PP}"
      # for QUIC auto-detection
      CPPFLAGS+=' -DHAVE_UINTPTR_T'
      LIBS+=' -lcrypt32'
      h3=1
    else
      options+=' --without-wolfssl'
    fi

    if [ -d ../mbedtls ]; then
      [ -n "${mainssl}" ] || mainssl='mbedtls'
      options+=" --with-mbedtls=${_TOP}/mbedtls/${_PP}"
    else
      options+=' --without-mbedtls'
    fi

    options+=' --without-gnutls --without-bearssl --without-rustls --without-hyper'

    if [ "${_OS}" = 'win' ]; then
      options+=' --with-schannel'
    elif [ "${_OS}" = 'mac' ] && [ "${_OSVER}" -lt '1015' ]; then
      # SecureTransport deprecated in 2019 (macOS 10.15 Catalina, iOS 13.0)
      options+=' --with-secure-transport'
      # Without this, SecureTransport becomes the default TLS backend
      [ -n "${mainssl}" ] && options+=" --with-default-ssl-backend=${mainssl}"
    elif [ -z "${mainssl}" ]; then
      options+=' --without-ssl'
    fi
    CPPFLAGS+=' -DHAS_ALPN'

  # options+=' --with-ca-fallback'
    options+=' --without-ca-fallback'

    if [ -d ../wolfssh ] && [ -d ../wolfssl ]; then
      options+=" --with-wolfssh=${_TOP}/wolfssh/${_PP}"
      CPPFLAGS+=" -I${_TOP}/wolfssh/${_PP}/include"
      LDFLAGS+=" -L${_TOP}/wolfssh/${_PP}/lib"
      options+=' --without-libssh'
      options+=' --without-libssh2'
    elif [ -d ../libssh ]; then
      options+=" --with-libssh=${_TOP}/libssh/${_PPS}"
      options+=' --without-wolfssh'
      options+=' --without-libssh2'
      CPPFLAGS+=' -DLIBSSH_STATIC'
    elif [ -d ../libssh2 ]; then
      options+=" --with-libssh2=${_TOP}/libssh2/${_PPS}"
      options+=' --without-wolfssh'
      options+=' --without-libssh'
      if [ "${_OS}" = 'win' ]; then
        LIBS+=' -lbcrypt'  # for auto-detection

        # Workaround for libssh2 1.11.0 regression:
        # Omit __declspec(dllimport) with libssh2 1.11.0 to link statically
        [ "${LIBSSH2_VER_}" = '1.11.0' ] && CPPFLAGS+=' -DLIBSSH2_API='
      fi
    else
      options+=' --without-wolfssh'
      options+=' --without-libssh'
      options+=' --without-libssh2'
    fi

    options+=' --without-librtmp'

    if [ -d ../libidn2 ]; then
      options+=" --with-libidn2=${_TOP}/libidn2/${_PP}"
      LDFLAGS+=" -L${_TOP}/libidn2/${_PP}/lib"
      LIBS+=' -lidn2'

      if [ -d ../libpsl ]; then
        options+=" --with-libpsl=${_TOP}/libpsl/${_PP}"
        CPPFLAGS+=" -I${_TOP}/libpsl/${_PP}/include"
        LDFLAGS+=" -L${_TOP}/libpsl/${_PP}/lib"
        LIBS+=' -lpsl'
      else
        options+=' --without-libpsl'
      fi

      if [ -d ../libiconv ]; then
        LDFLAGS+=" -L${_TOP}/libiconv/${_PP}/lib"
        LIBS+=' -liconv'
      fi
      if [ -d ../libunistring ]; then
        LDFLAGS+=" -L${_TOP}/libunistring/${_PP}/lib"
        LIBS+=' -lunistring'
      fi
    else
      options+=' --without-libidn2'
      options+=' --without-libpsl'
      if [ "${_CONFIG#*pico*}" = "${_CONFIG}" ] && \
         [ "${_OS}" = 'win' ]; then
        options+=' --with-winidn'
      fi
    fi

    if [ -d ../cares ]; then
      options+=" --enable-ares=${_TOP}/cares/${_PP}"
      CPPFLAGS+=' -DCARES_STATICLIB'
    else
      options+=' --disable-ares'
    fi

    if [ -d ../gsasl ]; then
      options+=" --with-libgsasl=${_TOP}/gsasl/${_PPS}"
      CPPFLAGS+=" -I${_TOP}/gsasl/${_PPS}/include"
      LDFLAGS+=" -L${_TOP}/gsasl/${_PPS}/lib"
    else
      options+=' --without-libgsasl'
      if [ "${_OS}" = 'mac' ]; then
        # GSS API deprecated in 2012-2013 (OS X 10.8 Mountain Lion / 10.9 Mavericks, iOS 7.0)
      # options+=' --with-gssapi'
        :
      fi
    fi

    if [ -d ../nghttp2 ]; then
      options+=" --with-nghttp2=${_TOP}/nghttp2/${_PP}"
      CPPFLAGS+=' -DNGHTTP2_STATICLIB'
    else
      options+=' --without-nghttp2'
    fi

    [ "${_CONFIG#*noh3*}" = "${_CONFIG}" ] || h3=0

    # We enable HTTP/3 manually, so it shows up "disabled" in 'configure summary'.
    if [ "${h3}" = '1' ] && [ -d ../nghttp3 ] && [ -d ../ngtcp2 ]; then
      # Detection insists on having a pkg-config, so force feed everything manually.
      # We enable this lib manually, so it shows up "disabled" in 'configure summary'.
      options+=' --with-nghttp3=yes'
      CPPFLAGS+=' -DNGHTTP3_STATICLIB -DUSE_NGHTTP3'
      CPPFLAGS+=" -I${_TOP}/nghttp3/${_PP}/include"
      LDFLAGS+=" -L${_TOP}/nghttp3/${_PP}/lib"
      LIBS+=' -lnghttp3'

      # Detection insists on having a pkg-config, so force feed everything manually.
      # We enable this lib manually, so it shows up "disabled" in 'configure summary'.
      options+=' --with-ngtcp2=yes'
      CPPFLAGS+=' -DNGTCP2_STATICLIB -DUSE_NGTCP2'
      CPPFLAGS+=" -I${_TOP}/ngtcp2/${_PPS}/include"
      LDFLAGS+=" -L${_TOP}/ngtcp2/${_PPS}/lib"
      LIBS+=' -lngtcp2'
      if [ "${_OPENSSL}" = 'boringssl' ] || [ "${_OPENSSL}" = 'awslc' ]; then
        LIBS+=' -lngtcp2_crypto_boringssl'
      elif [ "${_OPENSSL}" = 'quictls' ] || [ "${_OPENSSL}" = 'libressl' ]; then
        LIBS+=' -lngtcp2_crypto_quictls'
      elif [ -d ../wolfssl ]; then
        LIBS+=' -lngtcp2_crypto_wolfssl'
      fi
    else
      options+=' --without-nghttp3'
      options+=' --without-ngtcp2'
    fi

    if [ "${_OS}" = 'win' ]; then
      options+=' --enable-sspi'
    fi

    options+=' --without-quiche --without-msh3'

    options+=' --enable-threaded-resolver'
    if [ "${_OS}" = 'win' ]; then
      options+=' --disable-pthreads'
    else
      options+=' --enable-pthreads'
    fi

    options+=' --enable-websockets'

    if [ "${pass}" = 'shared' ]; then
      if [ "${_OS}" = 'win' ]; then
        _DEF_NAME="libcurl${_CURL_DLL_SUFFIX}.def"
        LDFLAGS+=" -Wl,--output-def,${_DEF_NAME}"
      fi

      options+=' --disable-static'
      options+=' --enable-shared'
    else
      options+=' --enable-static'
      options+=' --disable-shared'
    fi

    if [ -f "${cache}" ]; then
      grep -a -v -E '_env_(CPPFLAGS|LDFLAGS)_' "${cache}" > "${cache}.new"
      mv "${cache}.new" "${cache}"
    fi

    options+=" --cache-file=../${cache}"

    (
      mkdir "${_BLDDIR}-${pass}"; cd "${_BLDDIR}-${pass}"
      # shellcheck disable=SC2086
      ../configure ${options} \
        --disable-tls-srp \
        --enable-warnings \
        --enable-symbol-hiding \
        --enable-http \
        --enable-proxy \
        --enable-manual \
        --enable-libcurl-option \
        --enable-ipv6 \
        --enable-verbose \
        --enable-ntlm \
        --enable-cookies \
        --enable-http-auth \
        --enable-doh \
        --enable-mime \
        --enable-dateparse \
        --enable-netrc \
        --enable-progress-meter \
        --enable-dnsshuffle \
        --enable-get-easy-options \
        --enable-hsts \
        --without-ca-path \
        --without-ca-bundle
    )

    # NOTE: 'make clean' deletes src/tool_hugehelp.c and docs/curl.1. Next,
    #       'make' regenerates them, including the current date in curl.1,
    #       and breaking reproducibility. tool_hugehelp.c might also be
    #       reflowed/hyphened differently than the source distro, breaking
    #       reproducibility again. Skip the clean phase to resolve it.

    if [ "${pass}" = 'shared' ]; then
      # Skip building shared version curl tool. The build itself works, but
      # then autotools tries to create its "ltwrapper", and fails. This only
      # seems to happen when building curl against more than one dependency.
      # I have found no way to skip building that component, even though
      # we do not need it. Skip this pass altogether.
      VERSIONINFO='-avoid-version'
      [ -n "${_CURL_DLL_SUFFIX_NODASH}" ] && VERSIONINFO="-release '${_CURL_DLL_SUFFIX_NODASH}' ${VERSIONINFO}"
      make "VERSIONINFO=${VERSIONINFO}" \
        --directory="${_BLDDIR}-${pass}/lib" --jobs="${_JOBS}" install "DESTDIR=$(pwd)/${_PKGDIR}" # >/dev/null # V=1
    else
      make --directory="${_BLDDIR}-${pass}" --jobs="${_JOBS}" install "DESTDIR=$(pwd)/${_PKGDIR}" # >/dev/null # V=1
    fi

    # Manual copy to DESTDIR

    if [ "${_OS}" = 'win' ] && [ "${pass}" = 'shared' ]; then
      cp -p "${_BLDDIR}-${pass}/lib/${_DEF_NAME}" "${_PP}"/bin/
    fi

    if [ "${CW_MAP}" = '1' ]; then
      if [ "${pass}" = 'shared' ]; then
        cp -p "${_BLDDIR}-${pass}/lib/${_MAP_NAME}" "${_PP}/${DYN_DIR}/"
      else
        cp -p "${_BLDDIR}-${pass}/src/${_MAP_NAME}" "${_PP}"/bin/
      fi
    fi
  done

  # Build fixups

  chmod -x "${_PP}"/lib/*.a

  . ../curl-pkg.sh
)
