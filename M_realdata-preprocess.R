rm(list = ls(all = TRUE))

setwd("D:\\GitHub\\powerfamily\\data")

########################################################
# arcene (n = 42, p = 22283)
########################################################

load("arcene.rda")
arcene.x = tx
arcene.y = ty


########################################################
# breast (n = 42, p = 22283)
########################################################

load("breast.rda")
breast.x = x
breast.y = y


########################################################
# colon (n = 62, p = 2000)
########################################################

load("colon.rda")
x=colon.x
y=colon.y

########################################################
# leukemia (n = 72, p = 7128)
########################################################

load("leuk.rda")
x=lx.original
y=ly.original

########################################################
# prostate (n = 102, p = 6033)
########################################################

load("prostate.rda")
x=prostate.x
y=prostate.y
