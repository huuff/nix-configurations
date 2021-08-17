{
  smtpd = {
    type = "inet";
    private = false;
    chroot = false;
    command = "smtpd";
    name = "smtp";
  };

  pickup = {
    type = "unix";
    private = false;
    chroot = false;
    wakeup = 60;
    maxproc = 1;
    command = "pickup";
  };

  cleanup = {
    type = "unix";
    private = false;
    chroot = false;
    maxproc = 0;
    command = "cleanup";
  };

  qmgr = {
    type = "unix";
    private = false;
    chroot = false;
    wakeup = 300;
    maxproc = 1;
    command = "qmgr";
  };

  tlsmgr = {
    type = "unix";
    maxproc = 1;
    chroot = false;
    wakeup = 1000;
    command = "tlsmgr";
  };

  rewrite = {
    type = "unix";
    chroot = false;
    command = "trivial-rewrite";
  };

  bounce = {
    type = "unix";
    chroot = false;
    maxproc = 0;
    command = "bounce";
  };

  defer = {
    type = "unix";
    chroot = false;
    maxproc = 0;
    command = "bounce";
  };

  trace = {
    type = "unix";
    chroot = false;
    maxproc = 0;
    command = "bounce";
  };

  verify = {
    type = "unix";
    chroot = false;
    maxproc = 1;
    command = "verify";
  };

  flush = {
    type = "unix";
    private = false;
    maxproc = 0;
    chroot = false;
    wakeup = 1000;
    command = "flush";
  };

  proxymap = {
    type = "unix";
    chroot = false;
    command = "proxymap";
  };

  proxywrite = {
    type = "unix";
    chroot = false;
    command = "proxywrite";
  };

  smtp = {
    type = "unix";
    chroot = false;
    command = "smtp";
  };

  relay = {
    type = "unix";
    chroot = false;
    command = "smtp";
  };

  showq = {
    type = "unix";
    private = false;
    chroot = false;
    command = "showq";
  };

  error = {
    type = "unix";
    chroot = false;
    command = "error";
  };

  retry = {
    type = "unix";
    chroot = false;
    command = "error";
  };

  discard = {
    type = "unix";
    chroot = false;
    command = "discard";
  };

  local = {
    type = "unix";
    unpriv = false;
    chroot = false;
    command = "local";
  };

  virtual = {
    type = "unix";
    unpriv = false;
    chroot = false;
    command = "virtual";
  };

  lmtp = {
    type = "unix";
    chroot = false;
    command = "lmtp";
  };

  anvil = {
    type = "unix";
    chroot = false;
    maxproc = 1;
    command = "anvil";
  };

  scache = {
    type = "unix";
    chroot = false;
    maxproc = 1;
    command = "scache";
  };
}
