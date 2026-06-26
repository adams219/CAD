;;; GstarCAD / AutoCAD layout maker for drawings arranged in model space.
;;;
;;; 유지보수 메모
;;; - 목적: 모델 공간에 일렬 또는 여러 위치로 놓인 도면 프레임을 각각 배치 탭으로 만든다.
;;; - 기본 흐름:
;;;   1) GSA4GO에서 프레임 하나를 선택한다.
;;;   2) 필요하면 이름/레이어가 다른 프레임을 추가로 선택한다.
;;;   3) 선택한 샘플들과 같은 레이어/같은 객체 타입/비슷한 크기/같은 가로줄의 프레임들을 자동으로 찾는다.
;;;   4) 프레임 바운딩 박스의 좌하단(LL), 우상단(UR)을 모델 공간 창으로 저장한다.
;;;   5) 창 목록을 도면 읽는 순서대로 정렬한 뒤 SHEET-001, SHEET-002 순서로 배치를 만든다.
;;;   6) 각 배치에 A4 용지 설정, 뷰포트 생성, ZOOM Window, 뷰포트 잠금을 적용한다.
;;; - 스케일 원리: 모델 도면 자체는 바꾸지 않고, 뷰포트가 보는 모델 창 크기와 종이 크기의 비율로 축척이 정해진다.
;;;   예: 420 x 297 프레임을 297 x 210 A4에 넣으면 scale = 297 / 420 = 0.7071.
;;;
;;; Commands:
;;;   GSA4GO     - pick one frame, preview matching frames, confirm, then create A4 PDF layouts.
;;;   GSA4CHECK  - report whether the PDF plotter, A4 media, and CTB can be found.
;;;   GSA4CLEAN  - delete generated layouts whose names start with the current prefix.
;;;   GSA4VERIFY - report generated layout paper and viewport view values.
;;;   GSA4PDF    - plot generated layouts to individual PDF files.

(vl-load-com)

;;; 기본 출력/배치 설정값.
;;; 지금 실사용 기준에 맞춰 A4 full bleed, monochrome.ctb, SHEET-* 이름으로 고정해 둔다.
(setq *gsla-paper-width* 297.0)
(setq *gsla-paper-height* 210.0)
(setq *gsla-margin* 0.0)
(setq *gsla-prefix* "SHEET")
(setq *gsla-vport-layer* "GSLAYOUT_VIEWPORTS")
(setq *gsla-plot-device-candidates*
  '("DWG To PDF.pc3" "DWG TO PDF.pc3" "DWG To PDF" "DWG TO PDF")
)
(setq *gsla-media-candidates*
  '("ISO full bleed A4 (297.00 x 210.00 MM)"
    "ISO full bleed A4 (210.00 x 297.00 MM)"
    "ISO_full_bleed_A4_(297.00_x_210.00_MM)"
    "ISO_full_bleed_A4_(210.00_x_297.00_MM)"
    "ISO A4 (297.00 x 210.00 MM)"
    "ISO A4 (210.00 x 297.00 MM)"
    "ISO_A4_(297.00_x_210.00_MM)"
    "ISO_A4_(210.00_x_297.00_MM)"
  )
)
(setq *gsla-plot-style* "monochrome.ctb")
(setq *gsla-landscape-rotation* 0)
(setq *gsla-auto-size-tolerance* 0.20)
(setq *gsla-row-y-tolerance* 1.0)
(setq *gsla-row-overlap-ratio* 0.60)

;;; ---------------------------
;;; 공통 안전 호출/자료 변환 함수
;;; ---------------------------
;;; GstarCAD ActiveX 함수는 버전/상태에 따라 오류가 날 수 있으므로
;;; 실패 시 Lisp가 중단되지 않도록 vl-catch-all-apply로 감싼다.

(defun gsla-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun gsla-safe-call (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun gsla-call-ok-p (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (not (vl-catch-all-error-p result))
)

(defun gsla-safe-put-property (obj prop value / result)
  (setq result (vl-catch-all-apply 'vlax-put-property (list obj prop value)))
  (not (vl-catch-all-error-p result))
)

(defun gsla-safe-setvar (name value)
  (not
    (vl-catch-all-error-p
      (vl-catch-all-apply 'setvar (list name value))
    )
  )
)

(defun gsla-2d-point (x y / arr)
  (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-fill arr (list x y))
  (vlax-make-variant arr)
)

(defun gsla-dxf-put (data code value)
  (if (assoc code data)
    (subst (cons code value) (assoc code data) data)
    (append data (list (cons code value)))
  )
)

(defun gsla-real-value (value)
  (cond
    ((null value) nil)
    ((= (type value) 'VARIANT) (gsla-real-value (vlax-variant-value value)))
    ((= (type value) 'REAL) value)
    ((= (type value) 'INT) (float value))
    (T nil)
  )
)

(defun gsla-value->list (value)
  (cond
    ((null value) nil)
    ((= (type value) 'VARIANT) (gsla-value->list (vlax-variant-value value)))
    ((= (type value) 'SAFEARRAY) (vlax-safearray->list value))
    ((listp value) value)
    (T nil)
  )
)

;;; ---------------------------
;;; 이름 검색 함수
;;; ---------------------------
;;; 플로터/용지 이름은 GstarCAD, AutoCAD, 언어팩, PC3 설정에 따라
;;; 공백/밑줄/대소문자가 조금씩 다를 수 있다.
;;; 그래서 비교 전 알파벳과 숫자만 남겨 정규화한 이름도 함께 비교한다.

(defun gsla-normalize-name (name / idx ch code result)
  (setq idx 1)
  (setq result "")
  (if name
    (progn
      (setq name (strcase name))
      (while (<= idx (strlen name))
        (setq ch (substr name idx 1))
        (setq code (ascii ch))
        (if
          (or
            (and (>= code 65) (<= code 90))
            (and (>= code 48) (<= code 57))
          )
          (setq result (strcat result ch))
        )
        (setq idx (1+ idx))
      )
    )
  )
  result
)

(defun gsla-name-match-p (a b)
  (or
    (= (strcase a) (strcase b))
    (= (gsla-normalize-name a) (gsla-normalize-name b))
  )
)

(defun gsla-find-exact-ci (names candidates / result)
  (foreach candidate candidates
    (foreach name names
      (if (and (not result) name candidate (gsla-name-match-p name candidate))
        (setq result name)
      )
    )
  )
  result
)

(defun gsla-contains-ci-p (text token)
  (if (and text token (vl-string-search (strcase token) (strcase text)))
    T
    nil
  )
)

(defun gsla-starts-ci-p (text prefix)
  (if
    (and
      text
      prefix
      (>= (strlen text) (strlen prefix))
      (= (strcase (substr text 1 (strlen prefix))) (strcase prefix))
    )
    T
    nil
  )
)

(defun gsla-find-a4-media (names / result)
  (setq result (gsla-find-exact-ci names *gsla-media-candidates*))
  (if (not result)
    (foreach name names
      (if
        (and
          (not result)
          (gsla-contains-ci-p name "A4")
          (gsla-contains-ci-p name "297")
          (gsla-contains-ci-p name "210")
          (or
            (gsla-contains-ci-p name "full")
            (not (vl-some '(lambda (n) (gsla-contains-ci-p n "full")) names))
          )
        )
        (setq result name)
      )
    )
  )
  result
)

(defun gsla-first-settable-a4-media (layout / old-media current result)
  (setq old-media (gsla-safe-call 'vla-get-CanonicalMediaName (list layout)))
  (foreach media *gsla-media-candidates*
    (if
      (and
        (not result)
        (gsla-call-ok-p 'vla-put-CanonicalMediaName (list layout media))
      )
      (progn
        (setq current (gsla-safe-call 'vla-get-CanonicalMediaName (list layout)))
        (if (or (not current) (gsla-name-match-p current media))
          (setq result media)
        )
      )
    )
  )
  (if old-media
    (gsla-safe-call 'vla-put-CanonicalMediaName (list layout old-media))
  )
  result
)

(defun gsla-find-plot-style (names / result)
  (foreach name names
    (if (= (strcase name) (strcase *gsla-plot-style*))
      (setq result name)
    )
  )
  result
)

;;; PlotRotation 값은 내부적으로 0, 1, 2, 3으로 저장된다.
;;; 사람이 읽기 쉽게 0/90/180/270도로 표시한다.
(defun gsla-rotation-value-text (value)
  (setq value (gsla-real-value value))
  (cond
    ((null value) "<nil>")
    ((= value 0) "0")
    ((= value 1) "90")
    ((= value 2) "180")
    ((= value 3) "270")
    (T (rtos value 2 0))
  )
)

(defun gsla-rotation-text ()
  (gsla-rotation-value-text *gsla-landscape-rotation*)
)

;;; ---------------------------
;;; 모델 공간 프레임 창 계산
;;; ---------------------------
;;; 프레임 객체의 실제 끝점을 직접 찍는 대신 객체 바운딩 박스를 사용한다.
;;; 이 값이 사용자가 수동으로 좌하단/우상단 끝점을 찍은 것과 같은 역할을 한다.

(defun gsla-bbox (ename / obj mn mx result)
  (setq obj (vlax-ename->vla-object ename))
  (setq result (vl-catch-all-apply 'vla-getBoundingBox (list obj 'mn 'mx)))
  (if (vl-catch-all-error-p result)
    nil
    (list
      (vlax-safearray->list mn)
      (vlax-safearray->list mx)
    )
  )
)

(defun gsla-normalize-window (p1 p2 / x1 y1 x2 y2)
  (setq x1 (min (car p1) (car p2)))
  (setq y1 (min (cadr p1) (cadr p2)))
  (setq x2 (max (car p1) (car p2)))
  (setq y2 (max (cadr p1) (cadr p2)))
  (list (list x1 y1 0.0) (list x2 y2 0.0))
)

(defun gsla-window-width (win)
  (- (caadr win) (caar win))
)

(defun gsla-window-height (win)
  (- (cadadr win) (cadar win))
)

(defun gsla-window-baseline-y (win)
  (cadar win)
)

(defun gsla-window-landscape-p (win)
  (>= (abs (gsla-window-width win)) (abs (gsla-window-height win)))
)

(defun gsla-window-long-side (win)
  (max (abs (gsla-window-width win)) (abs (gsla-window-height win)))
)

(defun gsla-window-short-side (win)
  (min (abs (gsla-window-width win)) (abs (gsla-window-height win)))
)

(defun gsla-close-real-p (a b tolerance)
  (<= (abs (- a b)) (* (max (abs b) 1e-9) tolerance))
)

(defun gsla-window-similar-size-p (win reference tolerance)
  (and
    (gsla-close-real-p
      (gsla-window-long-side win)
      (gsla-window-long-side reference)
      tolerance
    )
    (gsla-close-real-p
      (gsla-window-short-side win)
      (gsla-window-short-side reference)
      tolerance
    )
  )
)

(defun gsla-window-same-baseline-p (win reference)
  (<=
    (abs (- (gsla-window-baseline-y win) (gsla-window-baseline-y reference)))
    *gsla-row-y-tolerance*
  )
)

(defun gsla-window-vertical-overlap (a b / bottom top)
  (setq bottom (max (cadar a) (cadar b)))
  (setq top (min (cadadr a) (cadadr b)))
  (max 0.0 (- top bottom))
)

(defun gsla-window-same-output-row-p (win reference / overlap shorter)
  (or
    (gsla-window-same-baseline-p win reference)
    (progn
      (setq overlap (gsla-window-vertical-overlap win reference))
      (setq shorter (min (abs (gsla-window-height win)) (abs (gsla-window-height reference))))
      (and
        (> shorter 1e-9)
        (>= (/ overlap shorter) *gsla-row-overlap-ratio*)
      )
    )
  )
)

(defun gsla-window-same-position-p (a b / tolerance)
  (setq tolerance *gsla-row-y-tolerance*)
  (and
    (<= (abs (- (caar a) (caar b))) tolerance)
    (<= (abs (- (cadar a) (cadar b))) tolerance)
    (<= (abs (- (caadr a) (caadr b))) tolerance)
    (<= (abs (- (cadadr a) (cadadr b))) tolerance)
  )
)

(defun gsla-add-window-if-new (item windows / exists existing)
  (setq exists nil)
  (foreach existing windows
    (if (gsla-window-same-position-p (cdr item) (cdr existing))
      (setq exists T)
    )
  )
  (if exists
    windows
    (cons item windows)
  )
)

(defun gsla-window-sheetlike-p (win / w h ratio)
  (setq w (abs (gsla-window-width win)))
  (setq h (abs (gsla-window-height win)))
  (if (and (> w 1e-9) (> h 1e-9))
    (progn
      (setq ratio (/ (max w h) (min w h)))
      (and (> ratio 1.20) (< ratio 1.60))
    )
    nil
  )
)

;;; 명령창에 감지 결과를 보기 좋게 출력하기 위한 좌표/창 문자열 함수.
(defun gsla-point-text (pt)
  (strcat
    "("
    (rtos (car pt) 2 2)
    ", "
    (rtos (cadr pt) 2 2)
    ")"
  )
)

(defun gsla-window-text (win)
  (strcat
    "size "
    (rtos (gsla-window-width win) 2 2)
    " x "
    (rtos (gsla-window-height win) 2 2)
    ", LL "
    (gsla-point-text (car win))
    ", UR "
    (gsla-point-text (cadr win))
  )
)

;;; 프레임 정렬 기준.
;;; 같은 행으로 볼 수 있는 작은 Y 오차는 허용하고, 같은 행에서는 왼쪽에서 오른쪽으로 정렬한다.
;;; 행이 다르면 위쪽 행부터 먼저 배치 이름을 붙인다.
(defun gsla-windows-same-row-p (a b / tolerance)
  (setq tolerance (* 0.10 (max (abs (gsla-window-height a)) (abs (gsla-window-height b)) 1.0)))
  (<= (abs (- (cadadr a) (cadadr b))) tolerance)
)

(defun gsla-sort-windows (items)
  (vl-sort
    items
    '(lambda (a b / aw bw)
       (setq aw (cdr a))
       (setq bw (cdr b))
       (if (gsla-windows-same-row-p aw bw)
         (< (caar aw) (caar bw))
         (> (cadadr aw) (cadadr bw))
       )
     )
  )
)

;;; ---------------------------
;;; 파일명/배치명 보조 함수
;;; ---------------------------
;;; 배치 이름과 PDF 파일명에 사용할 수 없는 문자를 밑줄로 바꾸고,
;;; 같은 이름이 있으면 _01, _02처럼 번호를 붙인다.

(defun gsla-replace-all (text old new / pos)
  (while (setq pos (vl-string-search old text))
    (setq text
      (strcat
        (substr text 1 pos)
        new
        (substr text (+ pos (strlen old) 1))
      )
    )
  )
  text
)

(defun gsla-clean-layout-name (name / bad)
  (foreach bad '("\\" "/" ":" "*" "?" "\"" "<" ">" "|" "," "=")
    (setq name (gsla-replace-all name bad "_"))
  )
  name
)

(defun gsla-clean-file-name (name / bad)
  (foreach bad '("\\" "/" ":" "*" "?" "\"" "<" ">" "|")
    (setq name (gsla-replace-all name bad "_"))
  )
  name
)

;;; PDF 출력 시 폴더와 파일명을 안전하게 합친다.
(defun gsla-path-join (folder file / last-char)
  (if (= folder "")
    file
    (progn
      (setq last-char (substr folder (strlen folder) 1))
      (if (or (= last-char "\\") (= last-char "/"))
        (strcat folder file)
        (strcat folder "\\" file)
      )
    )
  )
)

(defun gsla-unique-pdf-path (folder base / path n suffix)
  (setq path (gsla-path-join folder (strcat base ".pdf")))
  (setq n 1)
  (while (findfile path)
    (setq suffix (strcat "_" (if (< n 10) "0" "") (itoa n)))
    (setq path (gsla-path-join folder (strcat base suffix ".pdf")))
    (setq n (1+ n))
  )
  path
)

(defun gsla-layout-exists-p (name / doc layouts result)
  (setq doc (gsla-doc))
  (setq layouts (vla-get-Layouts doc))
  (setq result (vl-catch-all-apply 'vla-Item (list layouts name)))
  (not (vl-catch-all-error-p result))
)

(defun gsla-unique-layout-name (base / name n)
  (setq base (gsla-clean-layout-name base))
  (setq name base)
  (setq n 1)
  (while (gsla-layout-exists-p name)
    (setq name (strcat base "_" (if (< n 10) "0" "") (itoa n)))
    (setq n (1+ n))
  )
  name
)

;;; 뷰포트 테두리는 출력되지 않는 전용 레이어에 둔다.
;;; 도면 화면에서는 보이지만 PDF에는 찍히지 않게 Plottable을 false로 설정한다.
(defun gsla-ensure-vport-layer (/ doc layers layer)
  (setq doc (gsla-doc))
  (setq layers (vla-get-Layers doc))
  (setq layer (vl-catch-all-apply 'vla-Item (list layers *gsla-vport-layer*)))
  (if (vl-catch-all-error-p layer)
    (setq layer (vla-Add layers *gsla-vport-layer*))
  )
  (vl-catch-all-apply 'vla-put-Plottable (list layer :vlax-false))
  *gsla-vport-layer*
)

;;; 새 배치에는 기본 뷰포트가 자동으로 생길 수 있다.
;;; 우리가 만든 정확한 뷰포트만 쓰기 위해 번호 1을 제외한 기존 뷰포트를 삭제한다.
(defun gsla-delete-layout-viewports (layout-name / ss n ent data vp-no count)
  (setq ss (ssget "_X" (list '(0 . "VIEWPORT") (cons 410 layout-name))))
  (if ss
    (progn
      (setq n 0)
      (setq count 0)
      (while (< n (sslength ss))
        (setq ent (ssname ss n))
        (setq data (entget ent))
        (setq vp-no (cdr (assoc 69 data)))
        (if (and vp-no (> vp-no 1))
          (progn
            (entdel ent)
            (setq count (1+ count))
          )
        )
        (setq n (1+ n))
      )
      count
    )
    0
  )
)

;;; ---------------------------
;;; 배치 뷰포트 생성/맞춤
;;; ---------------------------

(defun gsla-viewport-entity-p (ename)
  (and
    ename
    (= (cdr (assoc 0 (entget ename))) "VIEWPORT")
  )
)

;;; GstarCAD에서는 vla-AddPViewport만으로 뷰포트가 안정적으로 잡히지 않는 경우가 있어
;;; 명령 방식 MVIEW를 먼저 시도하고, 실패하면 ActiveX 방식으로 다시 시도한다.
(defun gsla-add-paper-viewport (layout-name ll ur / doc ps width height center vp-obj vp-ent before after)
  (setq doc (gsla-doc))
  (setq ps (vla-get-PaperSpace doc))
  (setq width (abs (- (car ur) (car ll))))
  (setq height (abs (- (cadr ur) (cadr ll))))
  (setq center
    (list
      (+ (min (car ll) (car ur)) (/ width 2.0))
      (+ (min (cadr ll) (cadr ur)) (/ height 2.0))
      0.0
    )
  )

  (setq before (entlast))
  (vl-cmdf "_.MVIEW" "_non" ll "_non" ur)
  (setq after (entlast))
  (if (and after (/= after before) (gsla-viewport-entity-p after))
    (setq vp-ent after)
  )

  (if (not (gsla-viewport-entity-p vp-ent))
    (progn
      (setq before (entlast))
      (setq vp-obj
        (gsla-safe-call
          'vla-AddPViewport
          (list ps (vlax-3d-point center) width height)
        )
      )
      (if vp-obj
        (progn
          (gsla-safe-put-property vp-obj 'Display :vlax-true)
          (setq vp-ent (gsla-safe-call 'vlax-vla-object->ename (list vp-obj)))
          (if (not (gsla-viewport-entity-p vp-ent))
            (progn
              (setq after (entlast))
              (if (and after (/= after before) (gsla-viewport-entity-p after))
                (setq vp-ent after)
              )
            )
          )
        )
      )
    )
  )

  (if (not (gsla-viewport-entity-p vp-ent))
    (progn
      (setq before (entlast))
      (vl-cmdf "_.MVIEW" "_non" ll "_non" ur)
      (setq after (entlast))
      (if (and after (/= after before) (gsla-viewport-entity-p after))
        (setq vp-ent after)
      )
    )
  )

  (if (not (gsla-viewport-entity-p vp-ent))
    (princ (strcat "\nWarning: could not create viewport on " layout-name "."))
  )
  vp-ent
)

;;; 뷰포트가 모델 공간의 어떤 영역을 볼지 직접 설정한다.
;;; paper-ll/paper-ur는 종이 위 뷰포트 크기, model-window는 모델 공간 프레임 범위다.
;;; view-height를 종횡비에 맞춰 계산하고 CustomScale = paper-height / view-height로 둔다.
(defun gsla-fit-viewport-to-window (vp-ent vp-obj model-window paper-ll paper-ur / cx cy mw mh pw ph aspect view-height custom-scale data ok)
  (setq cx (/ (+ (caar model-window) (caadr model-window)) 2.0))
  (setq cy (/ (+ (cadar model-window) (cadadr model-window)) 2.0))
  (setq mw (abs (- (caadr model-window) (caar model-window))))
  (setq mh (abs (- (cadadr model-window) (cadar model-window))))
  (setq pw (abs (- (car paper-ur) (car paper-ll))))
  (setq ph (abs (- (cadr paper-ur) (cadr paper-ll))))
  (setq ok nil)
  (if (and (> mw 1e-9) (> mh 1e-9) (> pw 1e-9) (> ph 1e-9))
    (progn
      (setq aspect (/ pw ph))
      (setq view-height
        (if (> (/ mw mh) aspect)
          (/ mw aspect)
          mh
        )
      )

      (setq data (entget vp-ent))
      (setq data (gsla-dxf-put data 12 (list cx cy 0.0)))
      (setq data (gsla-dxf-put data 16 (list 0.0 0.0 1.0)))
      (setq data (gsla-dxf-put data 17 (list 0.0 0.0 0.0)))
      (setq data (gsla-dxf-put data 45 view-height))
      (setq data (gsla-dxf-put data 51 0.0))
      (setq data (gsla-dxf-put data 68 1))
      (if (entmod data)
        (setq ok T)
      )
      (entupd vp-ent)

      (if vp-obj
        (progn
          (gsla-safe-put-property vp-obj 'Target (vlax-3d-point (list 0.0 0.0 0.0)))
          (gsla-safe-put-property vp-obj 'Direction (vlax-3d-point (list 0.0 0.0 1.0)))
          (gsla-safe-put-property vp-obj 'TwistAngle 0.0)
          (if (gsla-safe-put-property vp-obj 'ViewCenter (gsla-2d-point cx cy))
            (setq ok T)
          )
          (if (gsla-safe-put-property vp-obj 'ViewHeight view-height)
            (setq ok T)
          )
          (setq custom-scale (/ ph view-height))
          (gsla-safe-put-property vp-obj 'StandardScale 0)
          (gsla-safe-put-property vp-obj 'CustomScale custom-scale)
        )
      )
    )
  )
  ok
)

;;; ActiveX 속성만으로는 일부 GstarCAD 버전에서 화면 갱신이 실제 뷰포트에 반영되지 않을 수 있다.
;;; 그래서 해당 뷰포트를 활성화한 뒤 ZOOM Window를 한 번 더 실행해 같은 위치 반복 문제를 방지한다.
;;; 이때 뷰포트 내부 모델공간의 GRIDMODE도 꺼서 생성된 배치 안에 그리드가 보이지 않게 한다.
(defun gsla-zoom-active-viewport-to-window (doc vp-obj model-window / ok)
  (setq ok nil)
  (if
    (and
      doc
      vp-obj
      (gsla-safe-put-property doc 'ActivePViewport vp-obj)
      (gsla-safe-put-property doc 'MSpace :vlax-true)
    )
    (progn
      (gsla-safe-setvar "GRIDMODE" 0)
      (if
        (not
          (vl-catch-all-error-p
            (vl-catch-all-apply
              'vl-cmdf
              (list "_.ZOOM" "_W" "_non" (car model-window) "_non" (cadr model-window))
            )
          )
        )
        (setq ok T)
      )
      (gsla-safe-put-property doc 'MSpace :vlax-false)
      (vl-cmdf "_.PSPACE")
      (gsla-safe-setvar "GRIDMODE" 0)
    )
  )
  ok
)

;;; 배치의 플롯 타입은 Layout 기준으로 맞추고, 용지 중앙 배치를 기본으로 둔다.
(defun gsla-configure-layout-for-fit (layout /)
  (gsla-safe-call 'vla-put-PaperUnits (list layout 1))
  (vl-catch-all-apply 'vla-put-PlotType (list layout 5))
  (vl-catch-all-apply 'vla-put-CenterPlot (list layout :vlax-true))
  (vl-catch-all-apply 'vla-put-UseStandardScale (list layout :vlax-true))
  (vl-catch-all-apply 'vla-put-StandardScale (list layout 0))
)

;;; 실제 GstarCAD가 보고 있는 용지 크기를 읽는다.
;;; 읽기에 실패하면 기본값 297 x 210을 사용한다.
(defun gsla-layout-paper-size (layout / width height result)
  (setq result (vl-catch-all-apply 'vla-GetPaperSize (list layout 'width 'height)))
  (setq width (gsla-real-value width))
  (setq height (gsla-real-value height))
  (if
    (and
      (not (vl-catch-all-error-p result))
      width
      height
      (> width 1e-9)
      (> height 1e-9)
    )
    (list width height)
    (list *gsla-paper-width* *gsla-paper-height*)
  )
)

(defun gsla-paper-size-for-window (layout model-window)
  (gsla-layout-paper-size layout)
)

;;; 프레임 방향과 용지 방향이 맞는지 확인한다.
;;; 현재 자동화는 가로 프레임이면 가로 A4, 세로 프레임이면 세로 A4를 목표로 한다.
(defun gsla-paper-size-matches-window-p (paper-size model-window / width height want-landscape)
  (setq width (car paper-size))
  (setq height (cadr paper-size))
  (setq want-landscape (gsla-window-landscape-p model-window))
  (and
    width
    height
    (if want-landscape
      (>= width height)
      (<= width height)
    )
  )
)

;;; A4 용지 이름과 회전값 조합을 바꿔 보며 프레임 방향에 맞는 설정을 찾는다.
(defun gsla-try-page-orientation (layout media rotation model-window / media-ok rotation-ok paper-size)
  (setq media-ok T)
  (if media
    (setq media-ok (gsla-call-ok-p 'vla-put-CanonicalMediaName (list layout media)))
  )
  (setq rotation-ok (gsla-call-ok-p 'vla-put-PlotRotation (list layout rotation)))
  (gsla-configure-layout-for-fit layout)
  (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
  (setq paper-size (gsla-layout-paper-size layout))
  (and
    media-ok
    rotation-ok
    (gsla-paper-size-matches-window-p paper-size model-window)
  )
)

;;; 배치를 만들 때 용지 방향이 프레임 방향과 맞지 않으면
;;; 사용 가능한 A4 용지 후보와 회전값을 순서대로 시험한다.
(defun gsla-adjust-page-orientation-for-window (layout model-window / old-media old-rotation medias media rotations rotation found)
  (setq old-media (gsla-safe-call 'vla-get-CanonicalMediaName (list layout)))
  (setq old-rotation (gsla-real-value (gsla-safe-call 'vla-get-PlotRotation (list layout))))
  (if (not old-rotation)
    (setq old-rotation *gsla-landscape-rotation*)
  )
  (setq old-rotation (fix old-rotation))

  (if (not (gsla-paper-size-matches-window-p (gsla-layout-paper-size layout) model-window))
    (progn
      (setq medias (append (if old-media (list old-media) nil) *gsla-media-candidates*))
      (setq rotations (list 0 1))
      (setq found nil)
      (foreach media medias
        (foreach rotation rotations
          (if (and (not found) (gsla-try-page-orientation layout media rotation model-window))
            (setq found T)
          )
        )
      )
      (if (not found)
        (progn
          (if old-media
            (gsla-safe-call 'vla-put-CanonicalMediaName (list layout old-media))
          )
          (gsla-safe-call 'vla-put-PlotRotation (list layout old-rotation))
          (gsla-configure-layout-for-fit layout)
          (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
        )
      )
      found
    )
    T
  )
)

;;; 플로터, 용지, CTB, 회전, Layout 플롯 타입을 한 번에 적용한다.
;;; GSA4CHECK와 GSA4VERIFY에서 보이는 기준값도 이 설정을 중심으로 맞춰진다.
(defun gsla-apply-page-setup (layout / layout-name devices medias device media device-ok media-ok style-ok rotation-ok)
  (setq layout-name (gsla-safe-call 'vla-get-Name (list layout)))
  (if (not layout-name) (setq layout-name "<layout>"))

  (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
  (setq devices (gsla-value->list (gsla-safe-call 'vla-GetPlotDeviceNames (list layout))))
  (setq device (gsla-find-exact-ci devices *gsla-plot-device-candidates*))
  (if (not device)
    (setq device (car *gsla-plot-device-candidates*))
  )
  (setq device-ok nil)
  (if device
    (setq device-ok (gsla-call-ok-p 'vla-put-ConfigName (list layout device)))
  )

  (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
  (setq medias (gsla-value->list (gsla-safe-call 'vla-GetCanonicalMediaNames (list layout))))
  (setq media (gsla-find-a4-media medias))
  (if (not media)
    (setq media (gsla-first-settable-a4-media layout))
  )
  (if (not media)
    (setq media (car *gsla-media-candidates*))
  )
  (setq media-ok nil)
  (if media
    (setq media-ok (gsla-call-ok-p 'vla-put-CanonicalMediaName (list layout media)))
  )

  (setq style-ok (gsla-call-ok-p 'vla-put-StyleSheet (list layout *gsla-plot-style*)))
  (setq rotation-ok (gsla-call-ok-p 'vla-put-PlotRotation (list layout *gsla-landscape-rotation*)))
  (gsla-configure-layout-for-fit layout)
  (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))

  (if (not device-ok)
    (princ (strcat "\nWarning: could not set plotter on " layout-name " to " device "."))
  )
  (if (not media-ok)
    (princ (strcat "\nWarning: could not set A4 media on " layout-name "."))
  )
  (if (not style-ok)
    (princ (strcat "\nWarning: could not set plot style on " layout-name " to " *gsla-plot-style* "."))
  )
  (if (not rotation-ok)
    (princ (strcat "\nWarning: could not set landscape rotation on " layout-name "."))
  )
  (and device-ok media-ok style-ok rotation-ok)
)

;;; 배치 하나를 만드는 핵심 함수.
;;; 1) 새 Layout 생성
;;; 2) A4 PDF 페이지 설정
;;; 3) 기존 뷰포트 제거
;;; 4) 종이 전체 크기의 뷰포트 생성
;;; 5) 모델 프레임 범위로 ZOOM Window
;;; 6) 종이공간/뷰포트 내부 GRIDMODE 끄기
;;; 7) 뷰포트 잠금
(defun gsla-make-layout (layout-name model-window / doc layouts layout paper-size paper-width paper-height ll ur vp-ent vp-obj)
  (setq doc (gsla-doc))
  (setq layouts (vla-get-Layouts doc))
  (setq layout (vla-Add layouts layout-name))
  (vla-put-ActiveLayout doc layout)
  (setvar "TILEMODE" 0)
  (vl-cmdf "_.PSPACE")
  (gsla-safe-setvar "GRIDMODE" 0)
  (gsla-apply-page-setup layout)
  (if (not (gsla-adjust-page-orientation-for-window layout model-window))
    (princ (strcat "\nWarning: could not align paper orientation on " layout-name "."))
  )
  (gsla-delete-layout-viewports layout-name)

  (setq paper-size (gsla-paper-size-for-window layout model-window))
  (setq paper-width (car paper-size))
  (setq paper-height (cadr paper-size))
  (setq ll (list *gsla-margin* *gsla-margin* 0.0))
  (setq ur
    (list
      (- paper-width *gsla-margin*)
      (- paper-height *gsla-margin*)
      0.0
    )
  )

  (setq vp-ent (gsla-add-paper-viewport layout-name ll ur))
  (if vp-ent
    (progn
      (setq vp-obj (vlax-ename->vla-object vp-ent))
      (gsla-safe-put-property vp-obj 'Layer *gsla-vport-layer*)
      (if (not (gsla-fit-viewport-to-window vp-ent vp-obj model-window ll ur))
        (princ (strcat "\nWarning: could not fit viewport view on " layout-name "."))
      )
      (if (not (gsla-zoom-active-viewport-to-window doc vp-obj model-window))
        (princ (strcat "\nWarning: could not command-zoom viewport on " layout-name "."))
      )
      (gsla-safe-setvar "GRIDMODE" 0)
      (gsla-safe-put-property vp-obj 'DisplayLocked :vlax-true)
      (gsla-safe-call 'vla-Regen (list doc 1))
    )
  )
  layout-name
)

;;; 여러 프레임 창을 SHEET-001부터 순서대로 배치로 만든다.
;;; UndoMark를 열어두기 때문에 GstarCAD에서 한 번의 Undo 흐름으로 되돌리기 쉽다.
(defun gsla-create-layouts (windows / *error* doc undo-open oldcmdecho items i base lname win)
  (defun *error* (msg)
    (if oldcmdecho (setvar "CMDECHO" oldcmdecho))
    (if (and doc undo-open)
      (gsla-safe-call 'vla-EndUndoMark (list doc))
    )
    (if
      (and
        msg
        (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      )
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (setq doc (gsla-doc))
  (setq undo-open nil)
  (setq oldcmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (if
    (not
      (vl-catch-all-error-p
        (vl-catch-all-apply 'vla-StartUndoMark (list doc))
      )
    )
    (setq undo-open T)
  )
  (gsla-ensure-vport-layer)
  (setq items (gsla-sort-windows windows))
  (setq i 1)
  (foreach item items
    (setq win (cdr item))
    (if (and (> (gsla-window-width win) 1e-9) (> (gsla-window-height win) 1e-9))
      (progn
        (setq base
          (strcat
            *gsla-prefix*
            "-"
            (if (< i 100) "0" "")
            (if (< i 10) "0" "")
            (itoa i)
          )
        )
        (setq lname (gsla-unique-layout-name base))
        (gsla-make-layout lname win)
        (princ (strcat "\nCreated layout: " lname))
        (setq i (1+ i))
      )
    )
  )
  (setvar "CMDECHO" oldcmdecho)
  (if undo-open
    (gsla-safe-call 'vla-EndUndoMark (list doc))
  )
  (princ (strcat "\nDone. Created " (itoa (1- i)) " layout(s)."))
  (princ)
)

;;; 첫 번째 프레임은 기준 가로줄을 정한다.
;;; 이후 추가로 선택한 프레임들은 이름/레이어가 다른 프레임 타입을 더 포함하기 위한 샘플이다.
;;; 각 샘플과 같은 레이어/같은 객체 타입을 전체 도면에서 찾되, 첫 번째 기준 가로줄과 겹치는 것만 배치 대상으로 삼는다.
;;; 원점 0,0 줄만 배치하려면 첫 번째로 LL이 0,0인 프레임을 선택하면 된다.
(defun gsla-auto-frame-windows (match-size / picked data etype layer ss n e bbox baseline-window sample-window win windows sample-count)
  (princ "\nPick the first drawing frame/title-block on the horizontal row to output.")
  (princ "\nThen pick additional frame types if the same row uses different frame names/layers.")
  (setq picked (car (entsel "\nFirst frame object: ")))
  (if picked
    (progn
      (setq bbox (gsla-bbox picked))
      (if bbox
        (progn
          (setq baseline-window (gsla-normalize-window (car bbox) (cadr bbox)))
          (princ
            (strcat
              "\nOutput row Y range: "
              (rtos (gsla-window-baseline-y baseline-window) 2 2)
              " to "
              (rtos (cadadr baseline-window) 2 2)
              " (baseline +/- "
              (rtos *gsla-row-y-tolerance* 2 2)
              ", overlap "
              (rtos (* *gsla-row-overlap-ratio* 100.0) 2 0)
              "%)"
            )
          )
          (setq windows nil)
          (setq sample-count 0)
          (while picked
            (setq data (entget picked))
            (setq etype (cdr (assoc 0 data)))
            (setq layer (cdr (assoc 8 data)))
            (setq bbox (gsla-bbox picked))
            (if bbox
              (progn
                (setq sample-window (gsla-normalize-window (car bbox) (cadr bbox)))
                (if (gsla-window-same-output-row-p sample-window baseline-window)
                  (progn
                    (setq sample-count (1+ sample-count))
                    (princ
                      (strcat
                        "\nFrame sample "
                        (itoa sample-count)
                        ": "
                        (gsla-window-text sample-window)
                      )
                    )
                    (setq ss (ssget "_X" (list (cons 0 etype) (cons 8 layer))))
                    (setq n 0)
                    (while (and ss (< n (sslength ss)))
                      (setq e (ssname ss n))
                      (setq bbox (gsla-bbox e))
                      (if bbox
                        (progn
                          (setq win (gsla-normalize-window (car bbox) (cadr bbox)))
                          (if
                            (and
                              (gsla-window-same-output-row-p win baseline-window)
                              (or
                                (and (not match-size) (gsla-window-sheetlike-p win))
                                (gsla-window-similar-size-p win sample-window *gsla-auto-size-tolerance*)
                              )
                            )
                            (setq windows (gsla-add-window-if-new (cons n win) windows))
                          )
                        )
                      )
                      (setq n (1+ n))
                    )
                  )
                  (princ "\nSkipped: selected frame does not overlap the output row.")
                )
              )
            )
            (setq picked
              (car
                (entsel
                  "\nAdditional frame object with another name/layer <Enter to continue>: "
                )
              )
            )
          )
          windows
        )
        (progn
          (princ "\nSelected frame has no readable bounding box.")
          nil
        )
      )
    )
    nil
  )
)

;;; 생성 전 감지된 프레임 개수와 좌표를 보여준다.
;;; 잘못 감지되면 여기서 No를 선택하고 도면 레이어/프레임을 정리하면 된다.
(defun gsla-preview-windows (windows / items total index win shown)
  (setq items (gsla-sort-windows windows))
  (setq total (length items))
  (princ (strcat "\nDetected sheet frame count: " (itoa total)))
  (if (> total 0)
    (progn
      (setq index 1)
      (setq shown 0)
      (foreach item items
        (if (< shown 20)
          (progn
            (setq win (cdr item))
            (princ
              (strcat
                "\n  "
                (if (< index 10) "0" "")
                (itoa index)
                ": "
                (gsla-window-text win)
              )
            )
            (setq shown (1+ shown))
          )
        )
        (setq index (1+ index))
      )
      (if (> total shown)
        (princ (strcat "\n  ... " (itoa (- total shown)) " more frame(s) not listed."))
      )
    )
  )
  (princ)
)

;;; GSA4GO의 실제 사용자 흐름.
;;; 미리보기 후 Yes/Enter일 때만 배치를 생성한다.
(defun gsla-preview-and-confirm-create (windows / answer)
  (gsla-preview-windows windows)
  (if windows
    (progn
      (initget "Yes No")
      (setq answer (getkword "\nCreate A4 PDF layouts from these frames? [Yes/No] <Yes>: "))
      (if (or (null answer) (= answer "Yes"))
        (gsla-create-layouts windows)
        (princ "\nNo layouts created.")
      )
    )
    (princ "\nNo matching sheet frames found.")
  )
  (princ)
)

;;; 자동 생성 배치는 prefix 기준으로만 관리한다.
;;; 기본값이면 SHEET-로 시작하는 배치만 정리/검증/PDF 출력 대상이다.
(defun gsla-generated-layout-names (/ doc layouts layout names name prefix)
  (setq doc (gsla-doc))
  (setq layouts (vla-get-Layouts doc))
  (setq names nil)
  (setq prefix (strcat *gsla-prefix* "-"))
  (vlax-for layout layouts
    (setq name (vla-get-Name layout))
    (if
      (and
        (/= (strcase name) "MODEL")
        (gsla-starts-ci-p name prefix)
      )
      (setq names (cons name names))
    )
  )
  (vl-sort names '<)
)

;;; 자동 생성된 SHEET-* 배치만 삭제한다.
;;; 사용자가 직접 만든 다른 이름의 배치와 모델 탭은 건드리지 않는다.
(defun gsla-clean-generated-layouts (/ answer doc layouts names layout count)
  (setq names (gsla-generated-layout-names))
  (if names
    (progn
      (princ
        (strcat
          "\nGenerated layouts found: "
          (itoa (length names))
          " layout(s) starting with "
          *gsla-prefix*
          "-."
        )
      )
      (initget "Yes No")
      (setq answer (getkword "\nDelete these generated layouts? [Yes/No] <No>: "))
      (if (= answer "Yes")
        (progn
          (setvar "TILEMODE" 1)
          (setq doc (gsla-doc))
          (setq layouts (vla-get-Layouts doc))
          (setq count 0)
          (foreach name names
            (setq layout (gsla-safe-call 'vla-Item (list layouts name)))
            (if layout
              (progn
                (gsla-safe-call 'vla-Delete (list layout))
                (setq count (1+ count))
              )
            )
          )
          (princ (strcat "\nDeleted " (itoa count) " generated layout(s)."))
        )
        (princ "\nNothing deleted.")
      )
    )
    (princ (strcat "\nNo generated layouts starting with " *gsla-prefix* "- were found."))
  )
  (princ)
)

;;; 현재 환경에서 PDF 플로터, A4 용지, CTB가 읽히는지 확인한다.
;;; 실제 배치를 만들기 전에 프린터/용지 이름 문제를 빠르게 찾기 위한 명령이다.
(defun gsla-check-page-setup (/ doc layout old-config devices device medias media styles style)
  (setq doc (gsla-doc))
  (setq layout (vla-get-ActiveLayout doc))
  (setq old-config (gsla-safe-call 'vla-get-ConfigName (list layout)))
  (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))

  (setq devices (gsla-value->list (gsla-safe-call 'vla-GetPlotDeviceNames (list layout))))
  (setq device (gsla-find-exact-ci devices *gsla-plot-device-candidates*))

  (if device
    (progn
      (gsla-safe-call 'vla-put-ConfigName (list layout device))
      (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
    )
  )

  (setq medias (gsla-value->list (gsla-safe-call 'vla-GetCanonicalMediaNames (list layout))))
  (setq media (gsla-find-a4-media medias))
  (if (not media)
    (setq media (gsla-first-settable-a4-media layout))
  )

  (setq styles (gsla-value->list (gsla-safe-call 'vla-GetPlotStyleTableNames (list layout))))
  (setq style (gsla-find-plot-style styles))

  (princ "\nGstarCAD layout automation check")
  (princ (strcat "\n  Plotter: " (if device device "NOT FOUND: DWG To PDF.pc3")))
  (princ (strcat "\n  A4 media: " (if media media "NOT FOUND: ISO full bleed A4")))
  (princ
    (strcat
      "\n  Plot style: "
      (cond
        (style style)
        (styles (strcat "NOT FOUND: " *gsla-plot-style*))
        (T "Could not read plot style list; script will still try monochrome.ctb")
      )
    )
  )
  (princ (strcat "\n  Generated layout prefix: " *gsla-prefix* "-001"))
  (princ (strcat "\n  Plot rotation: " (gsla-rotation-text)))
  (princ (strcat "\n  Existing generated layouts: " (itoa (length (gsla-generated-layout-names)))))
  (if old-config
    (progn
      (gsla-safe-call 'vla-put-ConfigName (list layout old-config))
      (gsla-safe-call 'vla-RefreshPlotDeviceInfo (list layout))
    )
  )
  (princ)
)

;;; ---------------------------
;;; 검증 출력 함수
;;; ---------------------------
;;; GSA4VERIFY는 배치가 실제로 어떤 용지/뷰포트/축척 값을 갖는지 명령창에 출력한다.
;;; 스케일이 중요한 도면은 여기의 view size와 scale을 확인한다.

(defun gsla-dxf-value (data code)
  (cdr (assoc code data))
)

(defun gsla-real-text (value)
  (setq value (gsla-real-value value))
  (if value
    (rtos value 2 4)
    "<nil>"
  )
)

(defun gsla-safe-point-text (pt)
  (if pt
    (gsla-point-text pt)
    "<nil>"
  )
)

(defun gsla-orientation-text (width height)
  (cond
    ((or (not width) (not height)) "unknown")
    ((>= width height) "landscape")
    (T "portrait")
  )
)

(defun gsla-orientation-status-text (paper-w paper-h view-w view-h / paper-orientation view-orientation)
  (setq paper-orientation (gsla-orientation-text paper-w paper-h))
  (setq view-orientation (gsla-orientation-text view-w view-h))
  (if
    (and
      (/= paper-orientation "unknown")
      (/= view-orientation "unknown")
      (= paper-orientation view-orientation)
    )
    "OK"
    "WARN"
  )
)

;;; 배치에 포함된 실제 뷰포트 엔티티를 찾는다.
;;; 번호 1은 종이 공간 자체의 시스템 뷰포트라 제외한다.
(defun gsla-viewport-entities-for-layout (layout-name / ss n ent data vp-no result)
  (setq ss (ssget "_X" (list '(0 . "VIEWPORT") (cons 410 layout-name))))
  (setq result nil)
  (if ss
    (progn
      (setq n 0)
      (while (< n (sslength ss))
        (setq ent (ssname ss n))
        (setq data (entget ent))
        (setq vp-no (gsla-dxf-value data 69))
        (if (and vp-no (> vp-no 1))
          (setq result (cons ent result))
        )
        (setq n (1+ n))
      )
    )
  )
  (reverse result)
)

;;; 한 배치의 플로터/용지/뷰포트 중심/모델 창 크기/축척을 출력한다.
(defun gsla-verify-one-layout (layouts name / layout config media rotation layout-paper-size layout-orientation viewports ent data vp-no paper-w paper-h view-center view-height view-width custom-scale)
  (setq layout (gsla-safe-call 'vla-Item (list layouts name)))
  (princ (strcat "\nLayout " name))
  (if layout
    (progn
      (setq config (gsla-safe-call 'vla-get-ConfigName (list layout)))
      (setq media (gsla-safe-call 'vla-get-CanonicalMediaName (list layout)))
      (setq rotation (gsla-safe-call 'vla-get-PlotRotation (list layout)))
      (setq layout-paper-size (gsla-layout-paper-size layout))
      (setq layout-orientation (gsla-orientation-text (car layout-paper-size) (cadr layout-paper-size)))
      (princ (strcat "\n  Plotter: " (if config config "<nil>")))
      (princ (strcat "\n  Media: " (if media media "<nil>")))
      (princ (strcat "\n  Plot rotation: " (gsla-rotation-value-text rotation)))
      (princ
        (strcat
          "\n  Layout paper size: "
          (rtos (car layout-paper-size) 2 4)
          " x "
          (rtos (cadr layout-paper-size) 2 4)
          " ("
          layout-orientation
          ")"
        )
      )

      (setq viewports (gsla-viewport-entities-for-layout name))
      (princ (strcat "\n  Viewports: " (itoa (length viewports))))
      (foreach ent viewports
        (setq data (entget ent))
        (setq vp-no (gsla-dxf-value data 69))
        (setq paper-w (gsla-dxf-value data 40))
        (setq paper-h (gsla-dxf-value data 41))
        (setq view-center (gsla-dxf-value data 12))
        (setq view-height (gsla-dxf-value data 45))
        (setq view-width nil)
        (setq custom-scale nil)
        (if (and paper-w paper-h view-height (/= paper-h 0.0))
          (progn
            (setq view-width (* view-height (/ paper-w paper-h)))
            (if (/= view-height 0.0)
              (setq custom-scale (/ paper-h view-height))
            )
          )
        )
        (princ
          (strcat
            "\n    VP "
            (if vp-no (itoa vp-no) "?")
            ": paper "
            (gsla-real-text paper-w)
            " x "
            (gsla-real-text paper-h)
            ", view center "
            (gsla-safe-point-text view-center)
            ", view size "
            (gsla-real-text view-width)
            " x "
            (gsla-real-text view-height)
            ", scale "
            (gsla-real-text custom-scale)
            ", orientation "
            (gsla-orientation-status-text paper-w paper-h view-width view-height)
          )
        )
      )
    )
    (princ "\n  <layout not readable>")
  )
  (princ)
)

;;; 모든 SHEET-* 배치를 순서대로 검증한다.
(defun gsla-verify-generated-layouts (/ doc layouts names)
  (setq doc (gsla-doc))
  (setq layouts (vla-get-Layouts doc))
  (setq names (gsla-generated-layout-names))
  (princ "\nGstarCAD generated layout verification")
  (princ (strcat "\n  Expected paper: " (rtos *gsla-paper-width* 2 1) " x " (rtos *gsla-paper-height* 2 1)))
  (princ (strcat "\n  Expected plot rotation: " (gsla-rotation-text)))
  (if names
    (foreach name names
      (gsla-verify-one-layout layouts name)
    )
    (princ (strcat "\nNo generated layouts starting with " *gsla-prefix* "- were found."))
  )
  (princ)
)

;;; ---------------------------
;;; PDF 출력
;;; ---------------------------
;;; SHEET-* 배치를 개별 PDF로 출력한다.
;;; 기존 PDF 파일이 있으면 덮어쓰지 않고 _01, _02 번호를 붙인다.

(defun gsla-plot-generated-layouts (/ *error* doc plot old-layout old-bg folder answer names layout file ok fail)
  (defun *error* (msg)
    (if old-bg (setvar "BACKGROUNDPLOT" old-bg))
    (if (and doc old-layout)
      (gsla-safe-call 'vla-put-ActiveLayout (list doc old-layout))
    )
    (if
      (and
        msg
        (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      )
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  (setq names (gsla-generated-layout-names))
  (if names
    (progn
      (setq folder (getvar "DWGPREFIX"))
      (if (= folder "")
        (setq folder (getvar "TEMPPREFIX"))
      )
      (setq folder
        (getstring
          T
          (strcat "\nPDF output folder <" folder ">: ")
        )
      )
      (if (= folder "")
        (setq folder (getvar "DWGPREFIX"))
      )
      (if (= folder "")
        (setq folder (getvar "TEMPPREFIX"))
      )

      (princ (strcat "\nGenerated layouts to plot: " (itoa (length names))))
      (princ (strcat "\nOutput folder: " folder))
      (initget "Yes No")
      (setq answer (getkword "\nPlot these layouts to individual PDF files? [Yes/No] <No>: "))
      (if (= answer "Yes")
        (progn
          (setq doc (gsla-doc))
          (setq old-layout (vla-get-ActiveLayout doc))
          (setq old-bg (getvar "BACKGROUNDPLOT"))
          (setvar "BACKGROUNDPLOT" 0)
          (setq plot (vla-get-Plot doc))
          (setq ok 0)
          (setq fail 0)
          (foreach name names
            (setq layout (gsla-safe-call 'vla-Item (list (vla-get-Layouts doc) name)))
            (if layout
              (progn
                (vla-put-ActiveLayout doc layout)
                (gsla-apply-page-setup layout)
                (setq file
                  (gsla-unique-pdf-path
                    folder
                    (gsla-clean-file-name name)
                  )
                )
                (if (gsla-safe-call 'vla-PlotToFile (list plot file))
                  (progn
                    (setq ok (1+ ok))
                    (princ (strcat "\nPDF created: " file))
                  )
                  (progn
                    (setq fail (1+ fail))
                    (princ (strcat "\nPDF failed: " file))
                  )
                )
              )
            )
          )
          (setvar "BACKGROUNDPLOT" old-bg)
          (if old-layout
            (gsla-safe-call 'vla-put-ActiveLayout (list doc old-layout))
          )
          (princ (strcat "\nDone. PDF success: " (itoa ok) ", failed: " (itoa fail) "."))
        )
        (princ "\nNo PDFs created.")
      )
    )
    (princ (strcat "\nNo generated layouts starting with " *gsla-prefix* "- were found."))
  )
  (princ)
)

;;; ---------------------------
;;; 사용자 명령
;;; ---------------------------
;;; 실제 명령은 유지보수를 위해 5개만 공개한다.

(defun c:GSA4GO (/ windows)
  (setvar "TILEMODE" 1)
  (setq windows (gsla-auto-frame-windows T))
  (gsla-preview-and-confirm-create windows)
  (princ)
)

(defun c:GSA4CHECK ()
  (gsla-check-page-setup)
)

(defun c:GSA4CLEAN ()
  (gsla-clean-generated-layouts)
)

(defun c:GSA4VERIFY ()
  (gsla-verify-generated-layouts)
)

(defun c:GSA4PDF ()
  (gsla-plot-generated-layouts)
)

;;; 예전 버전에 있던 실험용/우회용 명령이 이미 메모리에 로드되어 있을 수 있다.
;;; APPLOAD를 다시 했을 때 혼동되지 않도록 명령 심볼을 nil로 비운다.
(foreach sym
  '(c:GSA4PREVIEW
    c:GSA4AUTO
    c:GSA4PREVIEWLAYER
    c:GSA4LAYER
    c:GSA4SELECT
    c:GSA4WINDOW
    c:GSA4OBJ
    c:GSA4DIAG
    c:GSA4SETTINGS
    c:GSLAYOUTS
    c:GSLAYOUTSW
   )
  (set sym nil)
)

(princ "\nLoaded gstarcad_layout_from_model.lsp.")
(princ "\nCommands: GSA4CHECK, GSA4GO, GSA4VERIFY, GSA4CLEAN, GSA4PDF.")
(princ)
