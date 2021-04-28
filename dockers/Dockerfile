FROM ubuntu:18.04

WORKDIR /root/
# add repo and update
RUN dpkg --add-architecture i386 && apt-get update

# install basic libs and tools
RUN apt-get install -y build-essential gcc-multilib g++-multilib nasm bc

# install build tools
RUN apt-get install -y ninja-build cmake

# install network tools and "downloaders"
RUN apt-get install -y netcat socat git curl net-tools wget

# install debug tools
RUN apt-get install -y gdb gdb-multiarch ltrace strace

# install qemu
RUN apt-get install -y qemu-kvm qemu

# install required tools for creating images
RUN apt-get install -y sudo debootstrap

# install python ruby environment
RUN apt-get install -y python3-dev python3-pip ipython3 ruby-dev

# install vim with .vimrc
RUN apt-get install -y vim &&\
    git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime &&\ 
    bash ~/.vim_runtime/install_awesome_vimrc.sh

# install zshrc with oh-my-zsh
RUN apt-get install -y zsh && git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git /tmp/oh-my-zsh && cat /tmp/oh-my-zsh/tools/install.sh | zsh &&\
    sed -i "1,$ s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"ys\"/g" ~/.zshrc && \
    chsh -s /bin/zsh

# install tmux with .tmux
RUN apt-get install -y tmux && \
    git clone https://github.com/gpakosz/.tmux.git && \
    ln -s -f .tmux/.tmux.conf && cp .tmux/.tmux.conf.local .

# locale
RUN apt-get install -y locales && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# create-image


# clean
# RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD /bin/zsh
