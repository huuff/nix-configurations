def login(self):
    self.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
    self.succeed("useradd -m alice")
    self.succeed("(echo foobar; echo foobar) | passwd alice")
    self.wait_until_tty_matches(1, "login: ")
    self.send_chars("alice\n")
    self.wait_until_tty_matches(1, "login: alice")
    self.wait_until_succeeds("pgrep login")
    self.wait_until_tty_matches(1, "Password: ")
    self.send_chars("foobar\n")
    self.wait_until_succeeds("pgrep -u alice bash")

def outputs(self, command, output):
    [ _, out ] = self.execute(command)
    if (out != output and out != f'{output}\n'):
        raise AssertionError(f'Expected: {output} Got: {out}')

def outputContains(self, command, output):
    [ _, out ] = self.execute(command)
    if (output not in out):
        raise AssertionError(f'The string {output} is not in \n{out}\n')

def printOutput(self, command):
    [ _, out ] = self.execute(command)
    print(out)

Machine.login = login
Machine.outputs = outputs
Machine.outputContains = outputContains
Machine.printOutput = printOutput
del(login)
del(outputs)
del(outputContains)
del(printOutput)
