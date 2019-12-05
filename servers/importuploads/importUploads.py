version = 'importUploads  1.0.1  vom 18. Februar 2019'

from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.message import Message
from email import encoders
import os
import pysftp
import re
import shutil
import smtplib
import tarfile
import time

# sftp config
host='storage.vipcomag.eu'
user='comfax'
key='~/.ssh/id_rsa'
sourcedir='/home/software/zsipos/inbox'
#sourcedir='/home/software/zsipos/woso'

destdir='/usbdisk1/var/ZSipOs_Uploads/indir'
destURLprefix='\\\\vpcnas01\\usbdisk1\\var\\ZSipOs_Uploads\\indir\\'
SMto=['stefan.adams@vipcomag.de','woso@vipcomag.de','support@vipcomag.de']

pause = 100

# Mail config
SMme='woso@vipcomag.de'
SMhost='relay.vianetworks.de'
SMuser='vipcomagde'
SMpw='riosemunr7'

bad=re.compile('(^/|\.\.)')
sftp = None

def mailto (to,sub,text,cc=[],bcc=[],att=[]):
    def s2a(x):
        return x if type(x) == list else [x]
    msg=MIMEMultipart()
    msg['Subject'] = sub
    msg['From'] = SMme
    for i in s2a(to): msg['To'] = i
    for i in s2a(cc): msg['Cc'] = i
    msg['X-Mailer'] = version
    msg.attach(MIMEText(text,'plain','utf-8'))
    for i in s2a(att):
        if isinstance(i,Message):
            m=i
        else:
            fp=open(i,'rb')
            m=MIMEApplication(fp.read(),'binary')
            m.add_header('Content-Disposition','attachment',filename=i)
            fp.close()
        msg.attach(m)
    s=smtplib.SMTP(SMhost)
    r=s.starttls()
    s.login(SMuser,SMpw)
    d=s2a(to)+s2a(cc)+s2a(bcc)
#    print "ccs: %s"%(s2a(cc),)
#    print "recipients: %s"%(d,)
    s.sendmail(SMme,d,msg.as_string())
    r=s.quit()
    return r

def procfile(fn):
    prot=[]
    prot.append('processing %s\n'%(fn,))
    dirfn=os.path.join(destdir,fn)
    dtarfn=dirfn+'.tar'
    if os.path.exists(dirfn):
        prot.append('removing dir %s'%(dirfn,))
        shutil.rmtree(dirfn,ignore_errors=True)
    if os.path.exists(dtarfn):
        prot.append('removing file %s'%(dtarfn,))
        os.remove(dtarfn)
    sftp.get(fn,dtarfn)
    att=[]
    if tarfile.is_tarfile(dtarfn):
        files=set() # Menge der Files im Zielverzeichnis
        collisions=0
        t=tarfile.open(dtarfn,mode='r')
        for i in t:
            if bad.search(i.name):
                nfn=bad.sub('_',i.name)
                prot.append('bad filename "%s" replaced by "%s"'%(i.name,nfn))
                i.name=nfn
            while i.name in files:
                collisions += 1
                i.name = "%s_%d"%(i.name,collisions)
                prot.append('collision: name := %s'%(i.name,))
            files.add(i.name)
            i.mode=0o777 if i.isdir() else 0o440
            prot.append('extract %s, size = %d'%(i.name,i.size))
            t.extract(i,dirfn)  
        if 'Manifest' in files:
            att=os.path.join(dirfn,'Manifest')       
    else:
        if os.path.exists(dirfn):
            os.remove(dirfn)
        os.rename(dtarfn,dirfn)
        prot.append('%s is no tarfile'%(dirfn,))
    prot.append('\nstored in %s'%(dirfn,))
    sftp.remove(fn)
    prot.append('%s removed from %s:%s'%(fn,host,sourcedir))
    prot.append('URL: %s'%(destURLprefix+fn))
    mailto(SMto,'ZSipOs upload imported: %s'%(fn,),'\n'.join(prot),att=att)

    
def procfiles(sftp):
    for f in sftp.listdir():
        procfile(f)
    
print version
with pysftp.Connection(host, username=user, private_key=key) as sftp:
    with sftp.cd(sourcedir):             # temporarily chdir to public
#        sftp.put('entchen.txt')  # upload file to public/ on remote
        
        while True:
            procfiles(sftp)
            time.sleep (pause)
