.SUFFIXES:
SOURCE_TEX=*.tex
SOURCE_GNUPLOT=*.gpi
LOCAL_MAKEFILE=Makefile.local

# TODO:
#  - allow extra dependencies for foobar.pdf in local Makefile (use ::)
#  - extra target make list-images, make list-tex...
#  - using include $(RULES) instead of $(MAKE1), and GNU remaking of
# $(RULES) when necessary.
#  + inclusion of TeX files and packages/classes
#  - auto determine whether TeX / LaTeX / ConTeXt / LuaTeX / ...
#  - factor tex log coloring via a function
#  - allow empty colors
#  - prevent control going back to Makefile to allow calls such as
#    make -f /some/where/this/Makefile

SUBDIR=.make
RULES=$(SUBDIR)/rules.mk
RULES_PLACE=$(RULES)
MAKE1=$(MAKE) --no-print-directory

PDFLATEX=pdflatex
BIBTEX=bibtex
GNUPLOT=gnuplot
# Disable stupid dash echo that does not understand -e
ECHO=/bin/echo -e
SED=/bin/sed -r

# Colors
COLOR_FILE=$$(tput bold;tput setaf 4)
COLOR_WARNING=$$(tput setaf 9)
COLOR_FONT=$$(tput setaf 8)
COLOR_PACKAGE=$$(tput setaf 3)
COLOR_OVERFULL=$$(tput setaf 5)
COLOR_RESET=$$(tput sgr0)
SED_PROTECT=$(SED) -e 's/[[()\]/\\&/g'

.PHONY: all clean distclean rules rules-force one-pdf one-clean

all: rules
	@$(MAKE1) -f $(RULES) all

clean: rules
	@$(MAKE1) -f $(RULES) clean

distclean: rules
	@$(MAKE1) -f $(RULES) clean
	rm -rf $(SUBDIR)

# Rules for one file
# Target 'foobar.aux' is useful for forcing one single compilation
FORCE:
%.pdf: FORCE
	@$(MAKE1) -f $(RULES) $@

%.clean:
	@$(MAKE1) -f $(RULES) $(SUBDIR)/$@

# Global rules
rules:
	@(if [ -f $(RULES) ] ; then \
	  make --no-print-directory -f $(RULES) rules-comp; \
	else \
	  $(ECHO) "Creating $(RULES_PLACE)...";\
	  $(MAKE1) rules-force; \
	fi)

rules-force:
	@[ -d $(SUBDIR) ] || mkdir $(SUBDIR)
	@( $(ECHO) "# Auto generated" ;\
	$(ECHO) "\n# -- TeX files --" ;\
	rules_dep='';\
	if [ "$(SOURCE_TEX)" != x$(SOURCE_TEX) ] ; then \
	  rules_dep="$$rules_sep "$$($(ECHO) $(SOURCE_TEX)); \
	fi;\
	cp -f /dev/null $(SUBDIR)/all;\
	for s in $(SOURCE_TEX); do \
	  $(ECHO) "\n# -- Rules for $$s --" ;\
	  b=`basename $$s  .tex` ; bib="" ; bbl="" ;\
	  bib=$$($(SED) -ne 's/.*\\bibliography\{(.*)\}.*/\1,/p' < $$s \
	    | $(SED) -e 's/,/.bib /g');\
	  dep='';\
	  for p in $$($(SED) \
	    -ne \ 's/.*\\usepackage(\[[^]]*\])?\{([^}]*)\}.*/\2.sty/gp' \
	    -ne \ 's/.*\\documentclass(\[[^]]*\])?\{([^}]*)\}.*/\2.cls/gp' \
	    < $$s) ; do [ -f $$p ] && dep="$$dep $$p"; done;\
	  img_files_in=$$($(SED) -ne '/^ *%/d' -e  \
	    's/.*\\includegraphics(\[[^]]*\]|)\{([^}]*)\}.*/\2/gp'  < $$s \
	    | tr '\n' ' ');\
	  img_files=''; for f in $$img_files_in; do\
	    for e in .png .pdf .jpg .jpeg ; do\
	      if [ -f $$f$$e ] || grep -q $$f$$e *.gpi ; then\
	        img_files="$$img_files $$f$$e"; continue 2;\
	      fi;\
	    done;\
	  done;\
	  if [ "$$bib" ] ; then bbl="$$b.bbl" ; else bbl=""; fi; \
	  eval $$($(SED) -ne '/documentclass/q; s/\\/\\\\/g; \
	    s/^ *% *texflags *: */texflags=/p' $$s); \
	  M="\$$(MAKE) DEST=.make FILE='$$b' \
	    DEP='$$dep' BIB='$$bib' BBL='$$bbl' TEXFLAGS='$$texflags'";\
	  $(ECHO) "\n$$b.pdf: $$b.tex $$bib $$dep $(SUBDIR)/$$b.img\n\t"\
	  "@$$M one-pdf";\
	  $(ECHO) "\n$$b.clean: \n\t@$$M one-clean";\
	  $(ECHO) $$b >> $(SUBDIR)/all;\
	  sed -ne '/documentclass/ q; s/\\/\\\\/g; s/^% *variant *: *//p' $$s \
	  |  while read -r suffix prefix ; do \
	    prefix=$$($(ECHO) $$prefix | $(SED) -e 's/\\/\\\\/g');\
	    M1="$$M SUFFIX='$$suffix' PREFIX='$$prefix'";\
	    b1=$$b$$suffix;\
	    $(ECHO) "\n$$b1.pdf: $$b.tex $(SUBDIR)/$$b.img\n\t@$$M1 one-pdf";\
	    $(ECHO) "\n$$b1.aux: $$b.tex\n\t$$M1 \$$@";\
	    $(ECHO) "\n$$b1.clean: \n\t@$$M1 one-clean";\
	    $(ECHO) $$b1 >> $(SUBDIR)/all;\
	  done;\
	  $(ECHO) "\n$(SUBDIR)/$$b.img: $$img_files";\
	  $(ECHO) "\t@touch \$$@";\
	done ;\
	all=$$($(SED) -e "s/.*/&.pdf/" $(SUBDIR)/all | tr '\n' ' '); \
	clean=$$($(SED) -e "s/.*/&.clean/" $(SUBDIR)/all | tr '\n' ' '); \
	if [ "x$(SOURCE_GNUPLOT)" != "x$$($(ECHO) $(SOURCE_GNUPLOT))" ] ; then \
	rules_dep="$$rules_dep "$$($(ECHO) $(SOURCE_GNUPLOT)); \
	  $(ECHO) "\n# -- Gnuplot --" ;\
	for s in $(SOURCE_GNUPLOT); do \
	  out=$$($(SED) -ne "s/set\\s+output\\s+'([^']*)'/\\1/gp" < $$s \
	    | tr '\n' ' ' ); \
	  gnuplot_out="$$gnuplot_out $$out"; \
	  $(ECHO) "\n$$out: $$s\n\t$(GNUPLOT) $$s\n";\
	  clean="$$clean clean-gnuplot";\
	done ;\
	$(ECHO) "\nclean-gnuplot:\n\trm -f $$gnuplot_out";\
	fi;\
	$(ECHO) "\n# -- Global --\n";\
	$(ECHO) "\nall: all-auto\n\nall-auto: $$all";\
	$(ECHO) "\nclean: clean-auto\n\nclean-auto: $$clean";\
	$(ECHO) "\n.PHONY: all all-auto clean clean-auto";\
	$(ECHO) "\n# -- Recursivity --";\
	$(ECHO) "\nrules-comp:" ;\
	$(ECHO) "\t@\$$(MAKE) -f Makefile RULES_PLACE=$(SUBDIR)/rules.tmp\
	  rules-force";\
	$(ECHO) "\t@diff -q $(SUBDIR)/rules.tmp $(RULES) >/dev/null ||\
	  cp $(SUBDIR)/rules.tmp $(RULES)";\
	$(ECHO) "\t@rm -f $(SUBDIR)/rules.tmp";\
	if [ -f $(LOCAL_MAKEFILE) ] ; then \
	  $(ECHO) "\n# -- Local Makefile included --";\
	  $(ECHO) "# You may use automatic targets all-auto and clean-auto.";\
	  $(ECHO) "\ninclude $(LOCAL_MAKEFILE)";\
	fi;\
	) > $(RULES_PLACE)

#  	$(ECHO) "\n# -- Povray --" ;\
#  	for s in *.pov; do b=$${s%.pov} ;\
#  	  $(ECHO) "$$b.png: $$b.pov\n\t$(POVRAY) -i$$b.pov -o$$b.png\n" ;\
#  	done ;\
#  	$(ECHO) -n "povray-clean:\n\trm -f "; for f in *.pov; do \
#  	  $(ECHO) -n "$${f%pov}png " ;\
#  	done ; $(ECHO) ;\


# --- Rules for an individual file --
# This is included by rules.mk, while setting the following variables:
# FILE    = name of LaTeX source files
# PREFIX  = LaTeX commands before file inclusion (if any)
# SUFFIX  = suffix of job name (if any)
# TEXFLAGS= flags of PDFLaTeX
# SUBDIR  = directory of temporary files *.p1 etc.
# DEPS    = extra dependencies (if any) required for pdflatex compilation
# BIB      = bibliography .bib files (if any)
# BBL     = bibliography .bbl files (if any) for final compilation
F1=$(FILE)$(SUFFIX)
F2=$(SUBDIR)/$(F1)
COMMAND=pdflatex --jobname="$(F1)" $(TEXFLAGS) "$(PREFIX)\\input $(FILE)"

one-clean:
	rm -f $(F1).aux $(F1).toc $(F1).bbl $(F1).pdf $(F1).log \
	  $(F1).blg $(F1).vrb $(F1).out $(F1).nav $(F1).snm \
	  $(F2).*

one-pdf: $(F2).aux_aux
	@$(ECHO) $(COLOR_FILE)$(FILE).tex$(COLOR_RESET):
	@$(SED) -ne \
	"/^LaTeX Warning:/ { :a N; /\n\$$/!ba; s/\n\$$//;\
	s/^/$(COLOR_WARNING)/; s/\$$/$(COLOR_RESET)/; p; }; \
	/^LaTeX Font Warning:/ { :b N; /\n\$$/!bb; s/\n\$$//;\
	s/^/$(COLOR_FONT)/; s/\$$/$(COLOR_RESET)/; p; }; \
	/^(Package|Class) .* Warning:/ { :c N; /\n\$$/!bc; s/\n\$$//;\
	s/^/$(COLOR_PACKAGE)/; s/\$$/$(COLOR_RESET)/; p; }; \
	/^Overfull ..box/ { \
	s/^/$(COLOR_OVERFULL)/; s/\$$/$(COLOR_RESET)/; p; }; "\
	  < $(F1).log

# .aux_tex: .aux file newer than .tex file
# .aux_bbl: .aux file newer than .bbl files
# .aux_aux: stable .aux file
$(F2).aux_tex $(F1).aux: $(FILE).tex
	@$(COMMAND) || rm -f $(F1).pdf
	@touch $@

$(F2).aux_bib: $(BIB)
	@touch $@

$(F2).aux_bbl: $(F2).aux_tex $(F2).aux_bib
	bibtex $(F1)
	@diff -q $(F1).bbl $@ >/dev/null || $(COMMAND)
	@cp $(F1).bbl $@

$(F2).aux_aux: $(F2).aux_bbl
	@diff -q $(F1).aux $@ >/dev/null || $(COMMAND)
	@cp $(F1).aux $@
