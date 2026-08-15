# GMTITLE 사용자 선택 작업본 전환 이력

날짜: 2026-07-12
브랜치: `codex/gm-title`
LSP 버전: `260712-portable-saveas-workcopy-1`

## 변경 목적

기존 안전 가드는 변경 명령을 `C:\Users\<사용자>\Documents\CAD tool\work` 아래에서만 허용했다.
개발 중 원본 보호에는 유용했지만, 다른 사용자의 Windows 사용자명, 문서 폴더, 설치 드라이브와 실제 DWG 보관 위치를 강제하는 문제가 있었다.

고정 경로를 단순히 제거하면 원본 DWG를 직접 편집할 위험이 생기므로, 안전 기준을 경로에서 사용자 선택 작업본으로 바꿨다.

## 새 동작

원본 또는 아직 승인되지 않은 DWG에서 다음 명령을 처음 실행하면 파일 선택 창이 먼저 열린다.

```text
SWTITLEPREPARE
SWTITLECONVERTNEXT
SWTITLECONVERT
```

창 제목:

```text
SWTITLE 변환 작업본을 다른 이름으로 저장
```

사용자가 원하는 폴더와 새 파일명을 선택하면 다음 순서로 진행한다.

```text
현재 화면 상태를 새 DWG로 Save As
-> 활성 DWG 경로가 선택 경로와 같은지 확인
-> SWTITLE_SELECTED_WORKCOPY xdata 표식 기록
-> 표식까지 새 DWG에 저장
-> 기존 정리/변환 흐름 시작
```

선택을 취소하거나 원본과 같은 경로를 선택하면 변환하지 않는다. Save As, 활성 경로 확인, 작업본 표식 저장 중 하나라도 실패해도 변환하지 않는다.

## 재실행과 호환성

사용자 선택 작업본 표식은 Model Space 블록 레코드의 `SWTITLE_WORKCOPY` xdata에 저장한다.
따라서 작업본을 저장하고 다시 열어도 승인 상태를 유지한다.

저장소의 기존 `work` 폴더는 진단 및 회귀 테스트 호환성을 위해 계속 승인된 테스트 작업본으로 인정한다.
일반 사용자는 이 경로를 만들 필요가 없다.

## 다른 컴퓨터 지원

- 일반 로그는 `%LOCALAPPDATA%\SWTitle\logs`에 저장한다.
- 저장소 `work`에서 실행하는 기존 진단은 이전처럼 `work` 로그를 사용한다.
- GMTITLE 자동 선택 PowerShell은 고정 `work` 경로 대신 예상 DWG와 CAD 세션 로그의 실제 DWG 경로가 정확히 같은지 검사한다.
- 보조 PowerShell 파일은 현재 로드된 LSP 위치 또는 loader가 정한 저장소 루트를 기준으로 찾는다.

## 검증 상태

정적 preflight에서 다음 계약을 검사한다.

```text
LISP/PowerShell 구문 정상
Save As 취소 보호
원본과 같은 경로 거부
저장 후 활성 DWG 경로 확인
영구 작업본 표식 기록
공개 변경 명령의 공통 작업본 가드
상태 진단의 고정 work 경로 차단 제거
PowerShell 자동 선택의 고정 work 경로 차단 제거
```

실제 GstarCAD에서는 원본을 복사한 별도 임시 DWG로 다음을 검증했다.

```text
Save As result: yes
Persistent marker: yes
Authorization: user-selected-saveas-copy
Path match: yes
Portable helper found: yes
Local log root valid: yes
DBMOD after: 0
Result: PORTABLE_WORKCOPY_OK
```

GstarCAD를 종료하고 선택 작업본을 다시 열어도 같은 결과와 작업본 표식이 유지됐다.

```text
임시 원본 SHA256 전후 동일:
3C7735569B7EBAC8300225A81CEFB441562AB656770E5FC8868099B559A959B2

생성 로그:
tmp\portable-workcopy-probe\portable_workcopy_create.txt

재열기 로그:
tmp\portable-workcopy-probe\portable_workcopy_reopen_verify.txt
```

첫 실행에서는 Model Space 엔티티를 찾을 때 AutoLISP `or`의 반환값 `T`를 엔티티처럼 사용해
`인수 유형 오류: lentityp T`가 발생했다. `tblobjname` 결과를 지역변수에 보존하도록 수정한 뒤
같은 생성/종료/재열기 검사가 통과했다.

## 후속 전체 변환 검증

portable Save As 이후 A2/A3/A4 전체 자동 변환, 도면틀 정의의 용지 밖 중첩 INSERT 정리,
저장 후 재열기와 대표 편집창 검증까지 수행한 후속 이력은 아래 문서에 기록했다.

```text
docs\history\gmtitle-portable-e2e-offsheet-frame-2026-07-12.md
```
