/usr/bin/R CMD BATCH document.R
/usr/bin/R CMD build ../../
/usr/bin/R CMD check RPA_1.27.3.tar.gz
/usr/bin/R CMD INSTALL RPA_1.27.3.tar.gz

