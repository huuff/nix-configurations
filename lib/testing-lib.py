current_tty = 1

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def contains(actual, expected):
    if (expected not in actual):
        raise AssertionError(f"""
{Colors.FAIL}The string{Colors.ENDC}
{expected} 
{Colors.FAIL}is not in{Colors.ENDC}
{actual}
""")

def switch_tty(self, tty):
    global current_tty
    self.send_key(f"alt-f{tty}")
    self.wait_until_succeeds(f"[ $(fgconsole) = {tty} ]")
    current_tty = tty

def create_user(self, user):
    self.succeed(f"useradd -m {user}")
    self.succeed(f"(echo 'password'; echo 'password') | passwd {user}")

def login(self, user, tty=current_tty):
    self.wait_until_tty_matches(tty, "login: ")
    self.send_chars(f"{user}\n")
    self.wait_until_tty_matches(tty, f"login: {user}")
    self.wait_until_succeeds("pgrep login")
    self.wait_until_tty_matches(tty, "Password: ")
    self.send_chars("password\n")
    self.wait_until_succeeds(f"pgrep -u {user} bash")

# Create a user and login in the same command
def create_user_and_login(self, tty=current_tty, user="alice"):
    self.create_user(user)
    self.switch_tty(tty)
    self.login(user, tty)

def outputs(self, command, output):
    [ _, out ] = self.execute(command)
    if (out != output and out != f'{output}\n'):
        raise AssertionError(f'Expected: {output} Got: {out}')

# TODO: Better name for the argument, expected instead of output
def output_contains(self, command, output):
    [ _, out ] = self.execute(command)
    contains(out, output)

def print_output(self, command):
    [ _, out ] = self.execute(command)
    print(out)

def print_tty(self, tty=current_tty):
    out = self.get_tty_text(tty);
    print(out);

def put_tty(self, chars):
  self.send_chars(f"{chars}\n")
  self.wait_until_tty_matches(current_tty, chars)
  self.print_tty(current_tty)

Machine.login = login
Machine.create_user_and_login = create_user_and_login
Machine.create_user = create_user
Machine.outputs = outputs
Machine.output_contains = output_contains
Machine.print_output = print_output
Machine.switch_tty = switch_tty
Machine.print_tty = print_tty
Machine.put_tty = put_tty
del(login)
del(create_user_and_login)
del(create_user)
del(outputs)
del(output_contains)
del(print_output)
del(switch_tty)
del(print_tty)
del(put_tty)
