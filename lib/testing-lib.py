def login(machine):
    machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
    machine.succeed("useradd -m alice")
    machine.succeed("(echo foobar; echo foobar) | passwd alice")
    machine.wait_until_tty_matches(1, "login: ")
    machine.send_chars("alice\n")
    machine.wait_until_tty_matches(1, "login: alice")
    machine.wait_until_succeeds("pgrep login")
    machine.wait_until_tty_matches(1, "Password: ")
    machine.send_chars("foobar\n")
    machine.wait_until_succeeds("pgrep -u alice bash")

def outputs(machine, command, output):
    [ _, out ] = machine.execute(command)
    if (out != output and out != f'{output}\n'):
        raise AssertionError(f'Expected: {output} Got: {out}')

def outputContains(machine, command, output):
    [ _, out ] = machine.execute(command)
    if (output not in out):
        raise AssertionError(f'The string {output} is not in \n{out}\n')

def printOutput(machine, command):
    [ _, out ] = machine.execute(command)
    print(out)
