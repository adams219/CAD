;;; SWAUTO value regression probe.
;;;
;;; Loaded by run_swauto_value_test.ps1 in GstarCAD /b mode on a copied DWG.
;;; Records every dimension of the busiest tab before and after SWAUTO:
;;; the text GstarCAD actually draws (from the dimension block), measurement,
;;; DIMLFAC, tolerance values/flags and Mechanical fit data. The comparison is
;;; done outside CAD so it does not trust the module's own value guard.
;;;
;;; Environment:
;;;   SWAUTO_TEST_MODULE  dimstyle LSP to load
;;;   SWAUTO_TEST_MODE    "old" or "new" (new also runs SWAUTO a second time)
;;;   SWAUTO_TEST_LOG     log path

(vl-load-com)

(setq *swt-log* nil)

(defun swt-write (text)
  (if *swt-log* (write-line text *swt-log*))
)

(defun swt-say (text)
  (swt-write text)
  (princ (strcat "\n" text))
)

(defun swt-str (value)
  (cond
    ((= (type value) 'STR) value)
    ((null value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swt-num (value)
  (cond
    ((numberp value) (rtos (float value) 2 8))
    ((null value) "nil")
    (T (vl-princ-to-string value))
  )
)

(defun swt-clean (text / idx ch out)
  (setq out "")
  (setq idx 1)
  (while (<= idx (strlen text))
    (setq ch (substr text idx 1))
    (cond
      ((= ch "|") (setq out (strcat out "/")))
      ((member ch '("\n" "\r" "\t")) (setq out (strcat out " ")))
      (T (setq out (strcat out ch)))
    )
    (setq idx (1+ idx))
  )
  out
)

(defun swt-dstyle-overrides (data / apps acad pairs result)
  (setq apps (cdr (assoc -3 data)))
  (setq acad (assoc "ACAD" apps))
  (setq pairs (if acad (cdr acad) nil))
  (setq result nil)
  (while pairs
    (if (and (= (car (car pairs)) 1000) (equal (cdr (car pairs)) "DSTYLE"))
      (progn
        (setq pairs (cdr pairs))
        (while (and pairs (not (and (= (car (car pairs)) 1002) (equal (cdr (car pairs)) "}"))))
          (if (and (= (car (car pairs)) 1070) (cdr pairs) (/= (car (cadr pairs)) 1002))
            (progn
              (setq result (cons (cons (cdr (car pairs)) (cdr (cadr pairs))) result))
              (setq pairs (cddr pairs))
            )
            (setq pairs (cdr pairs))
          )
        )
      )
    )
    (if pairs (setq pairs (cdr pairs)))
  )
  result
)

(defun swt-effective (data overrides code / style record)
  (if (assoc code overrides)
    (cdr (assoc code overrides))
    (progn
      (setq style (cdr (assoc 3 data)))
      (setq record (if style (tblsearch "DIMSTYLE" style) nil))
      (if record (cdr (assoc code record)) nil)
    )
  )
)

(defun swt-block-text (data / name header ent ed kind out chunk item)
  (setq out "")
  (setq name (cdr (assoc 2 data)))
  (setq header (if name (tblobjname "BLOCK" name) nil))
  (setq ent (if header (entnext header) nil))
  (while ent
    (setq ed (entget ent))
    (setq kind (cdr (assoc 0 ed)))
    (if (or (null ed) (member kind '("ENDBLK" "SEQEND")))
      (setq ent nil)
      (progn
        (if (member kind '("MTEXT" "TEXT"))
          (progn
            (setq chunk "")
            (foreach item ed
              (if (= (car item) 3) (setq chunk (strcat chunk (cdr item))))
            )
            (setq chunk (strcat chunk (swt-str (cdr (assoc 1 ed)))))
            (setq out (strcat out "[" chunk "]"))
          )
        )
        (setq ent (entnext ent))
      )
    )
  )
  out
)

(defun swt-measurement (ent / value)
  (setq value
    (vl-catch-all-apply
      'vlax-get-property
      (list (vlax-ename->vla-object ent) 'Measurement)
    )
  )
  (if (vl-catch-all-error-p value) nil value)
)

;;; Geometric length for aligned (type 1) and rotated (type 0) linear dimensions.
(defun swt-geometric-length (data / p13 p14 flags dimtype angle)
  (setq p13 (cdr (assoc 13 data)))
  (setq p14 (cdr (assoc 14 data)))
  (setq flags (cdr (assoc 70 data)))
  (setq dimtype (if (numberp flags) (rem (fix flags) 8) nil))
  (setq angle (cdr (assoc 50 data)))
  (cond
    ((and p13 p14 (equal dimtype 1)) (distance p13 p14))
    ((and p13 p14 (equal dimtype 0) angle)
      (abs
        (+
          (* (- (car p14) (car p13)) (cos angle))
          (* (- (cadr p14) (cadr p13)) (sin angle))
        )
      )
    )
    (T nil)
  )
)

(defun swt-fit-info (data / app item out)
  (setq app (assoc "GENIUS_GENDTOL_13" (cdr (assoc -3 data))))
  (setq out "")
  (if app
    (foreach item (cdr app)
      (cond
        ((= (car item) 1040) (setq out (strcat out " nominal=" (swt-num (cdr item)))))
        ((and (= (car item) 1000) (<= (strlen (cdr item)) 8) (/= (cdr item) ""))
          (setq out (strcat out " code=" (cdr item)))
        )
      )
    )
  )
  out
)

(defun swt-record (ent / data overrides)
  (setq data (entget ent '("*")))
  (setq overrides (swt-dstyle-overrides data))
  (list
    (cdr (assoc 5 data))
    (cdr (assoc 3 data))
    (swt-effective data overrides 144)
    (swt-effective data overrides 71)
    (swt-effective data overrides 72)
    (swt-effective data overrides 47)
    (swt-effective data overrides 48)
    (swt-measurement ent)
    (cdr (assoc 42 data))
    (swt-geometric-length data)
    (swt-effective data overrides 271)
    (swt-effective data overrides 78)
    (swt-fit-info data)
    (cdr (assoc 1 data))
    (swt-block-text data)
  )
)

(defun swt-dimension-ss ()
  (ssget "_X" (list '(0 . "DIMENSION") (cons 410 (getvar "CTAB"))))
)

(defun swt-capture (/ ss idx result)
  (setq ss (swt-dimension-ss))
  (setq result nil)
  (setq idx 0)
  (if ss
    (while (< idx (sslength ss))
      (setq result (cons (swt-record (ssname ss idx)) result))
      (setq idx (1+ idx))
    )
  )
  (reverse result)
)

(defun swt-write-records (label records / record)
  (foreach record records
    (swt-write
      (strcat
        "REC|" label
        "|" (swt-clean (swt-str (nth 0 record)))
        "|" (swt-clean (swt-str (nth 1 record)))
        "|" (swt-num (nth 2 record))
        "|" (swt-num (nth 3 record))
        "|" (swt-num (nth 4 record))
        "|" (swt-num (nth 5 record))
        "|" (swt-num (nth 6 record))
        "|" (swt-num (nth 7 record))
        "|" (swt-num (nth 8 record))
        "|" (swt-num (nth 9 record))
        "|" (swt-num (nth 10 record))
        "|" (swt-num (nth 11 record))
        "|" (swt-clean (swt-str (nth 12 record)))
        "|" (swt-clean (swt-str (nth 13 record)))
        "|" (swt-clean (swt-str (nth 14 record)))
      )
    )
  )
)

;;; SWAUTO keeps working on CTAB, so use the tab that holds the most dimensions.
(defun swt-select-busiest-tab (/ ss idx tab counts pair best)
  (setq ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq counts nil)
  (setq idx 0)
  (if ss
    (while (< idx (sslength ss))
      (setq tab (cdr (assoc 410 (entget (ssname ss idx)))))
      (if (not tab) (setq tab "Model"))
      (setq pair (assoc tab counts))
      (if pair
        (setq counts (subst (cons tab (1+ (cdr pair))) pair counts))
        (setq counts (cons (cons tab 1) counts))
      )
      (setq idx (1+ idx))
    )
  )
  (setq best nil)
  (foreach pair counts
    (if (or (not best) (> (cdr pair) (cdr best)))
      (setq best pair)
    )
  )
  (foreach pair counts
    (swt-say (strcat "Tab dimensions: " (car pair) " = " (itoa (cdr pair))))
  )
  (if (and best (not (equal (strcase (car best)) (strcase (getvar "CTAB")))))
    (vl-catch-all-apply 'setvar (list "CTAB" (car best)))
  )
  (getvar "CTAB")
)

(defun swt-run-swauto (/ ss)
  (setq ss (swdt-current-space-dim-ss))
  (if (and ss (swdt-autofix-preflight ss))
    (swdt-run-autofix-core ss)
    nil
  )
)

(defun swt-result-text (result)
  (cond
    ((vl-catch-all-error-p result) (strcat "ERROR " (vl-catch-all-error-message result)))
    (result "OK")
    (T "CHECK_NEEDED")
  )
)

(defun swt-main (/ module mode log-path load-result result records)
  (setq module (getenv "SWAUTO_TEST_MODULE"))
  (setq mode (getenv "SWAUTO_TEST_MODE"))
  (setq log-path (getenv "SWAUTO_TEST_LOG"))
  (setq *swt-log* (open log-path "w"))
  (swt-say "SWAUTO value probe")
  (swt-say (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swt-say (strcat "Mode: " (swt-str mode)))
  (swt-say (strcat "ACADVER: " (swt-str (getvar "ACADVER"))))
  (swt-say (strcat "Tab: " (swt-select-busiest-tab)))
  (setq records (swt-capture))
  (swt-say (strcat "Dimensions: " (itoa (length records))))
  (swt-write-records "BEFORE" records)
  (setq load-result (vl-catch-all-apply 'load (list module)))
  (swt-say (strcat "Module load: " (if (vl-catch-all-error-p load-result) (vl-catch-all-error-message load-result) "OK")))
  (swt-say (strcat "Module version: " (swt-str *swdt-version*)))
  (setq result (vl-catch-all-apply 'swt-run-swauto nil))
  (swt-say (strcat "SWAUTO run 1: " (swt-result-text result)))
  (vl-catch-all-apply 'vl-cmdf (list "_.REGENALL"))
  (swt-write-records "AFTER" (swt-capture))
  (if (equal mode "new")
    (progn
      (setq result (vl-catch-all-apply 'swt-run-swauto nil))
      (swt-say (strcat "SWAUTO run 2: " (swt-result-text result)))
      (vl-catch-all-apply 'vl-cmdf (list "_.REGENALL"))
      (swt-write-records "AFTER2" (swt-capture))
    )
  )
  (setq result
    (vl-catch-all-apply
      'vla-Save
      (list (vla-get-ActiveDocument (vlax-get-acad-object)))
    )
  )
  (swt-say (strcat "Saved copy: " (if (vl-catch-all-error-p result) (vl-catch-all-error-message result) "yes")))
  (swt-say "SWAUTO value probe completed: yes")
  (close *swt-log*)
  (setq *swt-log* nil)
  (princ)
)

(swt-main)
