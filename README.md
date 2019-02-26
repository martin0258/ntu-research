university-research
============

university research work

# Run
To run R codes, you need to install all the R packages used.  
To know what packages to install, you can run codes and check the error message of missing package.  
Note that Package [Defaults] was removed from the CRAN repository, so please download it and install it manually.  
The installation command is as below:

```r
install.packages("PATH_TO_SOURCE_FOLDER/Defaults_1.1-1.tar.gz", repos = NULL, type="source")
```

# Presentation
Write in markdown, and generate PDF with pandoc.

```
pandoc oral.md -o oral.pdf -t beamer -V theme:Madrid -V toc:true
```

[Defaults]: http://cran.r-project.org/web/packages/Defaults/index.html
