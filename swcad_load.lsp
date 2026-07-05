;;; SWCAD loader for GstarCAD / GstarCAD Mechanical automation tools.
;;;
;;; Daily use:
;;;   APPLOAD this file, then run SWAUTO or diagnostic commands.

(vl-load-com)

(setq *swcad-version* "260706-loader-convert-next-response-guidance")

(defun swcad-loader-source (/ src)
  (setq src nil)
  (if (and (boundp '*load-truename*) *load-truename*)
    (setq src *load-truename*)
  )
  (if (not src)
    (setq src (findfile "swcad_load.lsp"))
  )
  src
)

(defun swcad-loader-root-valid-p (dir)
  (and
    dir
    (findfile (strcat dir "/src/tools/gmtitle/swcad_title_scale.lsp"))
  )
)

(defun swcad-loader-parent-dir (dir / clean)
  (setq clean (if dir (vl-string-right-trim "\\/" dir) nil))
  (if clean (vl-filename-directory clean) nil)
)

(defun swcad-loader-root (/ src dir dwg-dir dwg-parent user-root)
  (setq src (swcad-loader-source))
  (setq dir (if src (vl-filename-directory src) nil))
  (setq dwg-dir (getvar "DWGPREFIX"))
  (setq dwg-parent (swcad-loader-parent-dir dwg-dir))
  (setq user-root
    (if (getenv "USERPROFILE")
      (strcat (getenv "USERPROFILE") "/Documents/CAD tool")
      nil
    )
  )
  (cond
    ((swcad-loader-root-valid-p dir) dir)
    ((swcad-loader-root-valid-p dwg-dir) dwg-dir)
    ((swcad-loader-root-valid-p dwg-parent) dwg-parent)
    ((swcad-loader-root-valid-p user-root) user-root)
    (dir dir)
    (T ".")
  )
)

(setq *swcad-root* (swcad-loader-root))

(defun swcad-path (relative)
  (strcat *swcad-root* "/" relative)
)

(defun swcad-load-file (relative / path result)
  (setq path (swcad-path relative))
  (cond
    ((findfile path)
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (progn
          (princ (strcat "\nSWCAD 모듈 로드 실패: " relative))
          (princ (strcat "\n  " (vl-catch-all-error-message result)))
          nil
        )
        (progn
          (princ (strcat "\nSWCAD 모듈 로드 완료: " relative))
          T
        )
      )
    )
    (T
      (princ (strcat "\nSWCAD 모듈 없음: " relative))
      nil
    )
  )
)

(princ (strcat "\nSWCAD 도구 모음 로드 중 " *swcad-version* "..."))

(swcad-load-file "src/lsp/swcad_common.lsp")
(swcad-load-file "src/lsp/swcad_config.lsp")
(swcad-load-file "src/lsp/swcad_dimstyle.lsp")
(swcad-load-file "src/lsp/swcad_mechfit.lsp")
(swcad-load-file "src/tools/gmtitle/swcad_title_scale.lsp")
(swcad-load-file "src/lsp/swcad_cleanup.lsp")
(swcad-load-file "src/lsp/swcad_debug.lsp")

;;; The current production command set is kept intact until modular migration.
(swcad-load-file "src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp")

(princ "\nSWCAD 준비 완료.")
(princ "\n주 명령어: SWAUTO")
(princ "\n도움말: SWHELP")
(princ "\nGMTITLE 작업 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERTNEXT, SWTITLEVERIFY")
(princ "\nGMTITLE 수동 응답을 직접 고를 때만 SWTITLECONVERT를 사용하세요.")
(princ "\nGMTITLE CONVERTNEXT: YES/OPEN/BATCH/MANUAL은 다시 입력하지 말고 GMTITLE 창만 확인하세요.")
(princ "\nGMTITLE 창 확인: DR_A*_Outline, DR_titlea_3rd, Frame positioning ON, Object move OFF.")
(princ "\nGMTITLE 중요: 변환 전에는 항상 SWTITLESTATUS로 현재 열린 DWG와 다음 상태를 먼저 확인하세요.")
(princ "\nGMTITLE 금지: CAD 명령줄에 GMTITLE, TIT, 일반 OPEN을 직접 입력해 우회하지 마세요.")
(princ "\nGMTITLE 참고: 예전 SWTITLE transfer/fast/A3A4/frame-only 직접 명령은 사용하지 말고 위 흐름을 사용하세요.")
(princ "\n로드된 LSP 확인: SWTITLEVERSION")
(princ)
