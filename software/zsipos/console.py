class ConsoleOutput(object):

    def __init__(self):
        try:
            self.f = open('/tmp/zsiposfifo', 'w')
        except:
            self.f = None

    def info(self, msg):
        self.write(msg + "\n")
        
    def clear(self):
        if self.f:
            self.f.write("#clear\n")
            self.f.flush()

    def write(self, msg):
        if not self.f:
            print(msg)
            return
        self.f.write(msg)
        self.f.flush()


console = ConsoleOutput()
