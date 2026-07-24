# 専門レビューの選び方

controllerの通常reviewだけでは独立した専門性が足りない場合に限り、該当するreviewerを選ぶ。

- code-quality：新しいpattern、既存codebaseとの不整合、複雑さや重複が主要risk
- security：認証・認可、untrusted input、secret、injection、SSRF、権限境界に触れる
- architecture：module境界、public API、schema、migration、複数consumerへの波及が主要risk

利用中harnessにnative subagentがあれば、選んだ`agents/reviewer-*.md`の内容、対象snapshot、変更意図、repo規約、関連testをself-contained promptで渡す。custom agent fileを前提にしない。使えない場合は必要な観点だけcontrollerがinlineで見る。

独立した専門軸と利用可能なcapacityの範囲で並列化する。行数やfile数だけでは起動しない。返されたfindingはcontrollerがfile:lineとtestで裏取りし、重複を除いて優先順に並べる。
