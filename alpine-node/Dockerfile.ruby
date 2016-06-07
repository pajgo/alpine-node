FROM gliderlabs/alpine:3.4

ENV NODE_VERSION=v6.2.1 \
    NPM_VERSION=3 \
    RUBY_MAJOR=2.3 \
    RUBY_VERSION=2.3.1 \
    RUBY_DOWNLOAD_SHA256=b87c738cb2032bf4920fef8e3864dc5cf8eae9d89d8d523ce0236945c5797dcd \
    RUBYGEMS_VERSION=2.6.4 \
    BUNDLER_VERSION=1.12.4 \
    GEM_HOME=/usr/local/bundle \
	  BUNDLE_SILENCE_ROOT_WARNING=1

ENV BUNDLE_PATH="$GEM_HOME" \
	  BUNDLE_BIN="$GEM_HOME/bin" \
	  BUNDLE_APP_CONFIG="$GEM_HOME"

ENV PATH $BUNDLE_BIN:$PATH

RUN \
  mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  && set -ex \
  && apk add --no-cache --update --virtual .builddeps \
		bison \
		bzip2 \
		bzip2-dev \
		ca-certificates \
		coreutils \
		gdbm-dev \
		glib-dev \
		libc-dev \
		libffi-dev \
		libxml2-dev \
		libxslt-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		procps \
    # https://bugs.ruby-lang.org/issues/11869 and https://github.com/docker-library/ruby/issues/75
		readline-dev \
		ruby \
		yaml-dev \
		zlib-dev \
    autoconf \
    binutils-gold \
    curl \
    g++ \
    gcc \
    git \
    libgcc \
    libstdc++ \
    linux-headers \
    make \
    paxctl \
    python \
  && curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
  && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src \
  && tar -xzf ruby.tar.gz -C /usr/src \
	&& mv "/usr/src/ruby-$RUBY_VERSION" /usr/src/ruby \
	&& rm ruby.tar.gz \
	&& cd /usr/src/ruby \
	&& { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
	&& autoconf \
	# the configure script does not detect isnan/isinf as macros
	&& ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
		./configure --disable-install-doc \
	&& make -j"$(getconf _NPROCESSORS_ONLN)" \
	&& make install \
  && cd / \
  && curl -sSL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}.tar.gz | tar -xz \
  && cd /node-${NODE_VERSION} \
  && ./configure --prefix=/usr ${CONFIG_FLAGS} \
  && make -j"$(getconf _NPROCESSORS_ONLN)" \
  && make install \
  && paxctl -cm /usr/bin/node \
  && cd / \
  && if [ -x /usr/bin/npm ]; then \
    npm install -g npm@${NPM_VERSION} && \
    find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf; \
  fi \
  && runDeps="$( \
    scanelf --needed --nobanner --recursive /usr/local \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
  )" \
  && apk add --virtual .rundeps $runDeps \
    libstdc++ \
    libgcc \
  && apk del .builddeps \
  && gem update --system $RUBYGEMS_VERSION \
  && rm -rf /node-${NODE_VERSION} \
    /usr/src/ruby \
    /usr/share/man /tmp/* /root/.npm /root/.node-gyp \
    /usr/lib/node_modules/npm/man /usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/html \
  && gem install bundler --version "$BUNDLER_VERSION" \
  && mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
  && chmod 777 "$GEM_HOME" "$BUNDLE_BIN" \
  && adduser -S node

CMD [ "npm", "start" ]