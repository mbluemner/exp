from anki.hooks import addHook
from aqt import mw
from aqt.utils import showInfo
from aqt.qt import *
import os, random

N = 50
MonstersPath = "/home/jay/Downloads/anki-monster-pngs"

def loadMonster():
    path = random.choice(os.listdir(MonstersPath))
    pixmap = QPixmap(path)
    return pixmap

def monster():
    newCount, lrnCount, revCount = mw.col.sched.counts()
    totalCount = (newCount + lrnCount + revCount)
    howManyToDo = totalCount / 2
    if howManyToDo < N:
        howManyToDo = N
    if totalCount < N:
        howManyToDo = totalCount

    mw.monsterToDo = howManyToDo
    mw.monstersDone = 0
    mw.monsters = [ loadMonster() for n in range(howManyToDo)]

    if mw.monsterToDo > 0:
        displayMonsters()
        mw.moveToState("review")

def displayMonsters():
    parent = mw.app.activeWindow() or mw
    mb = QDialog(parent)
    mb.setWindowModality(Qt.WindowModal)
    mb.show()

    grid = QGridLayout()
    grid.setMargin(0)
    grid.setVerticalSpacing(0)
    grid.setHorizontalSpacing(0)
    grid.setRowStretch(1, 100)
    grid.setRowMinimumHeight(2, 6)

    dead = QLabel("Dead: %d" % mw.monstersDone)
    grid.addWidget( dead, 0, 0 )

    alive = QLabel("Alive: %d" % mw.monsterToDo)
    grid.addWidget( alive, 1, 0 )

    b = QPushButton("Shoot")
    b.setDefault(True)
    mb.connect(b, SIGNAL('clicked()'), mb.accept)
    grid.addWidget( mb, 2, 0 )

    print "About to setLayout"

    # XXX This causes a hang and doesn't display anything
    mb.setLayout(grid)

    print "About to exec"

    mb.exec_()

def monsterAnswerCard(card, ease):
    if ease == 1:
        return

    mw.monstersDone = mw.monstersDone + 1
    mw.monsterToDo = mw.monsterToDo - 1

    displayMonsters()

    if mw.monsterToDo <= 0:
        mw.moveToState("deckBrowser")

addHook('answerCard', monsterAnswerCard)

action = QAction("Monster", mw)
mw.connect(action, SIGNAL("triggered()"), monster)
mw.form.menuTools.addAction(action)
