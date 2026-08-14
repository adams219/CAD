# GMTITLE selection config deep registry check - 2026-07-06

## 목적

GMTITLE 창에서 `DR_A*_Outline` / `DR_titlea_3rd`를 사람이 고르지 않고 자동으로 고정할 수 있는 로컬 설정값이 있는지 다시 확인했다.

이번 확인은 실제 DWG를 열거나 수정하지 않는 읽기 전용 조사다.

## 실행

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics\gmtitle-main45\run_gmtitle_selection_config_probe.ps1 -DeepRegistrySearch
```

일반 sandbox 실행에서는 AppData/Registry 일부가 `Access denied` 또는 `missing`처럼 보일 수 있어, 실제 권한으로 다시 실행했다.

## 확인 결과

`PaperSet.ini`, `PaperSet.dat`, `PaperSet.grx`, AppData 텍스트 설정, `PAPERSET.GRX-66` 대화상자 registry key에서는 `DR_A*_Outline` / `DR_titlea_3rd`를 GMTITLE 기본 선택값으로 고정하는 근거를 찾지 못했다.

Deep registry search에서 아래 항목은 발견됐다.

```text
HKEY_CURRENT_USER\Software\Gstarsoft\...\Recent File List :: File7=...\Dwg\Title\DR_titlea_3rd.dwg
HKEY_CURRENT_USER\Software\Gstarsoft\...\Recent File List :: File8=...\Dwg\Format\DR_A4_Outline.dwg
```

하지만 이것은 최근 직접 열었던 파일 기록이다. GMTITLE 대화상자의 현재 용지/제목블록 선택값이나 preselection 설정으로 보지 않는다.

## 결론

현재 확인된 로컬 설정만으로는 GMTITLE 창을 `DR_A*_Outline` / `DR_titlea_3rd`로 안전하게 자동 선택할 근거가 없다.

따라서 기본 흐름은 유지한다.

```text
SWTITLECONVERTNEXT가 후보 판별, 배치점, 값 복사, 기존 객체 정리를 자동 처리
사람은 GMTITLE 창에서 DR 용지/DR_titlea_3rd/Frame positioning ON/Object move OFF만 확인
```

앞으로 command-line `-GMTITLE` 또는 내부 API 자동 선택을 실험하려면, work 복사본에서 실제 native INSERT/xdata와 더블클릭 동작이 같은지 별도 opt-in probe로 검증해야 한다.
