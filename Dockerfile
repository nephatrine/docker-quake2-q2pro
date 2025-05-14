# SPDX-FileCopyrightText: 2025 Daniel Wolf <nephatrine@gmail.com>
# SPDX-License-Identifier: ISC

# hadolint global ignore=DL3007,DL3018

FROM code.nephatrine.net/nephnet/nxb-alpine:latest AS builder

RUN git -C /root clone --single-branch --depth=1 https://github.com/skullernet/q2pro.git
WORKDIR /root/q2pro
RUN meson setup /tmp/q2pro/build \
  && meson configure -Dprefix=/opt/quake2 /tmp/q2pro/build \
  && meson compile -C /tmp/q2pro/build \
  && ninja -C /tmp/q2pro/build install

COPY override/usr/local/bin/quake2-gamename /usr/local/bin/

ARG CTF_VERSION=CTF_1_12
RUN git -C /root clone -b "$CTF_VERSION" --single-branch --depth=1 https://github.com/yquake2/ctf.git
WORKDIR /root/ctf
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mv release/game.so "release/$(quake2-gamename)"

ARG XATRIX_VERSION=XATRIX_2_15
RUN git -C /root clone -b "$XATRIX_VERSION" --single-branch --depth=1 https://github.com/yquake2/xatrix.git
WORKDIR /root/xatrix
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mv release/game.so "release/$(quake2-gamename)"

ARG ROGUE_VERSION=ROGUE_2_14
RUN git -C /root clone -b "$ROGUE_VERSION" --single-branch --depth=1 https://github.com/yquake2/rogue.git
WORKDIR /root/rogue
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mv release/game.so "release/$(quake2-gamename)"

RUN git -C /root clone --single-branch --depth=1 https://github.com/yquake2/zaero.git
WORKDIR /root/zaero
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mv release/game.so "release/$(quake2-gamename)"

RUN git -C /root clone --single-branch --depth=1 https://github.com/yquake2/pakextract.git
WORKDIR /root/pakextract
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 ))

RUN git -C /root clone --single-branch --depth=1 https://github.com/DirtBagXon/3zb2-zigflag.git \
  && if [ ! "$(uname -m)" = "x86_64" ]; then sed -i "s~-msse2 -mfpmath=sse~~g" /root/3zb2-zigflag/Makefile; fi
WORKDIR /root/3zb2-zigflag
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mv release/game.so "release/$(quake2-gamename)" \
  && mv 3zb2/pak10.pak 3zb2/pak6.pak

RUN git -C /root clone --single-branch --depth=1 https://github.com/QwazyWabbitWOS/lmctf60.git \
  && sed -i 's~ldd -r~ldd~g' /root/lmctf60/GNUmakefile
WORKDIR /root/lmctf60
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mkdir release \
  && mv game*.so "release/$(quake2-gamename)"

RUN git -C /root clone --single-branch --depth=1 https://github.com/skullernet/openffa.git
WORKDIR /root/openffa
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mkdir release \
  && mv game*.so "release/$(quake2-gamename)"

# hadolint ignore=SC2016
RUN git -C /root clone --single-branch --depth=1 https://github.com/packetflinger/opentdm.git \
  && sed -i "s~shell pkg-config libcurl --cflags~shell curl-config --cflags~g" /root/opentdm/Makefile \
  && sed -i "s~shell pkg-config libcurl --libs~shell curl-config --libs~g" /root/opentdm/Makefile \
  && sed -i "s~-DCURL_STATICLIB~~g" /root/opentdm/Makefile \
  && sed -i 's~deps/[^ ]*~$(CURL_LIBS)~g' /root/opentdm/Makefile
WORKDIR /root/opentdm
RUN make -j$(( $(getconf _NPROCESSORS_ONLN) / 2 + 1 )) \
  && mkdir release \
  && mv game*.so "release/$(quake2-gamename)"

FROM code.nephatrine.net/nephnet/alpine-s6:latest
LABEL maintainer="Daniel Wolf <nephatrine@gmail.com>"

RUN apk add --no-cache sdl2 tmux \
 && mkdir -p /mnt/shared /mnt/mirror \
 && rm -rf /tmp/* /var/tmp/*

COPY --from=builder /root/pakextract/pakextract /usr/local/bin/
COPY --from=builder /opt/quake2/ /opt/quake2/
COPY --from=builder /root/ctf/release/ /opt/quake2/lib/q2pro/ctf/
COPY --from=builder /root/xatrix/release/ /opt/quake2/lib/q2pro/xatrix/
COPY --from=builder /root/rogue/release/ /opt/quake2/lib/q2pro/rogue/
COPY --from=builder /root/zaero/release/ /opt/quake2/lib/q2pro/zaero/
COPY --from=builder /root/3zb2-zigflag/release/ /opt/quake2/lib/q2pro/3zb2/
COPY --from=builder /root/3zb2-zigflag/3zb2/ /opt/quake2/share/q2pro/3zb2/
COPY --from=builder /root/openffa/release/ /opt/quake2/lib/q2pro/openffa/
COPY --from=builder /root/opentdm/release/ /opt/quake2/lib/q2pro/opentdm/
COPY --from=builder /root/lmctf60/release/ /opt/quake2/lib/q2pro/lmctf/
COPY override /

RUN mv /opt/quake2/share/q2pro /opt/quake2/share/default
RUN echo "====== PREP FOR Q2ADMIN ======" \
 && cp "/opt/quake2/lib/q2pro/baseq2/$(quake2-gamename)" /opt/quake2/lib/q2pro/baseq2/game.real.so \
 && cp "/opt/quake2/lib/q2pro/ctf/$(quake2-gamename)" /opt/quake2/lib/q2pro/ctf/game.real.so \
 && cp "/opt/quake2/lib/q2pro/xatrix/$(quake2-gamename)" /opt/quake2/lib/q2pro/ctf/game.real.so \
 && cp "/opt/quake2/lib/q2pro/rogue/$(quake2-gamename)" /opt/quake2/lib/q2pro/ctf/game.real.so \
 && cp "/opt/quake2/lib/q2pro/zaero/$(quake2-gamename)" /opt/quake2/lib/q2pro/ctf/game.real.so \
 && cp "/opt/quake2/lib/q2pro/3zb2/$(quake2-gamename)" /opt/quake2/lib/q2pro/3zb2/game.real.so \
 && cp "/opt/quake2/lib/q2pro/openffa/$(quake2-gamename)" /opt/quake2/lib/q2pro/openffa/game.real.so \
 && cp "/opt/quake2/lib/q2pro/opentdm/$(quake2-gamename)" /opt/quake2/lib/q2pro/opentdm/game.real.so \
 && cp "/opt/quake2/lib/q2pro/lmctf/$(quake2-gamename)" /opt/quake2/lib/q2pro/lmctf/game.real.so

EXPOSE 27910/udp
