FROM ghcr.io/homebrew/brew:latest

USER root
RUN apt-get update && apt-get install -y zsh git curl && rm -rf /var/lib/apt/lists/*

COPY --chown=linuxbrew:linuxbrew . /home/linuxbrew/.dotfiles

WORKDIR /home/linuxbrew/.dotfiles
USER linuxbrew
ENV HOME=/home/linuxbrew \
    DOTFILES_DIR=/home/linuxbrew/.dotfiles

CMD ["bash", "-c", "bash install.sh && bash tests/verify.sh"]
