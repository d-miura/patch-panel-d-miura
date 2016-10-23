# 課題内容 (パッチパネルの機能拡張)
>パッチパネルに機能を追加しよう。
>
>授業で説明したパッチの追加と削除以外に、以下の機能をパッチパネルに追加してください。
>
>1. ポートのミラーリング
>2. パッチとポートミラーリングの一覧
>
>それぞれ patch_panel のサブコマンドとして実装してください。
>
>なお 1 と 2 以外にも機能を追加した人には、ボーナス点を加点します。                         



---

#解答
##0. エラーとすべきパッチ操作への処理(拡張課題)
この課題は[成元君のレポート](https://github.com/handai-trema/patch-panel-r-narimoto/blob/master/report.md#bug)の記述を参考に行った．

課題用リポジトリのdevelopブランチの/lib/patch_panel.rbでもともとなされている実装では，コントローラーが管理する各パッチパネルに属するパッチはインスタンス変数@patchで宣言時から1次元の配列として管理されている．
本来，パッチパネルは中継器なのでポートは二股になってはいけない(例えばport1とport2，port1とport3をつなぐパッチが同時に存在しないし，特に二股にするのであればミラーのような処理として行う必要がある)という前提を考えるとパッチの追加と削除さえ正しく行われるのであれば，パッチパネルに登録されるスイッチは1次元の配列でも構わない．

しかし，この実装では+演算子によって配列の連結を，-演算子は差集合を行っている．このため例えば下記の例で示すように，，もし，dｐid=0xabcとなるパッチパネルにport1とport2，port3とport4をつなぐパッチを順に作成した後に，(そもそも存在しない)port1とport3をつなぐパッチの削除ができてしまう．すると，@patcｈにはそもそも存在しないport2とport4をつなぐパッチの情報が保持されてしまううえ，フローテーブルの内容もport1とport3から上がってきたパケットを処理するフローエントリが削除されてしまうので，port2からport1へパケットを流すフローエントリとport4からport3へパケットを流すフローエントリのみが残されてしまう.

```
ensyuu2@ensyuu2-VirtualBox:~$ irb
2.2.5 :001 > patch = Hash.new{[]}
 => {}
2.2.5 :002 > patch[0xabc] += [1,2].sort
 => [1, 2]
2.2.5 :003 > patch[0xabc] += [3,4].sort
 => [1, 2, 3, 4]
2.2.5 :004 > patch[0xabc] -= [1,3].sort
 => [2, 4]
```
```
$ ./bin/patch_panel create 0xabc 1 2
$ ./bin/patch_panel create 0xabc 3 4
$ ./bin/patch_panel delete 0xabc 1 3
$ ./bin/trema dump_flows patch_panel
NXST_FLOW reply (xid=0x4):
 cookie=0x0, duration=1027.5s, table=0, n_packets=0, n_bytes=0, idle_age=1027, priority=0,in_port=4 actions=output:3
 cookie=0x0, duration=1031.437s, table=0, n_packets=0, n_bytes=0, idle_age=1031, priority=0,in_port=2 actions=output:1
```

また，developブランチの/lib/patch_panel.rbではswitch_readyハンドラも@patchが二次元配列を前提とした実装になっている．

そこで，拡張課題として

 * インスタンス変数@patchは2次元配列として管理
 * ポートが二股となるようなパッチの追加した(既存のパッチと同一のパッチは追加した)場合エラーメッセージを表示
 * 存在しないパッチを削除した場合エラーメッセージを表示

という処理を追加した．
###0.1 コード
####0.1.1 /lib/patch_panel.ｒｂへの追記内容
start,create_patch,delete_patchの各ハンドラの処理を変更した．
####0.1.2 /bin/patch_panelhへの追記内容
コードの変更は行わなかった．
###0.2 動作確認
以下の手順で動作確認を行った
 1. host1とhost2をつなぐパッチを作成
 2. host3とhost4をつなぐパッチを作成
 3. host１とhost3をつなぐパッチを作成
 4. host2とhost4をつなぐパッチを削除
 5. host3とhost4をつなぐパッチを削除

実行結果は以下のようになった．
```
(trema runプロセス) PatchPanel started.
$ ./bin/patch_panel create 0xabc 1 2
$ ./bin/patch_panel create 0xabc 3 4
$ ./bin/patch_panel create 0xabc 1 3
(trema runプロセス) Duplicated patch is designated.
$ ./bin/trema dump_flows patch_panel
NXST_FLOW reply (xid=0x4):
 cookie=0x0, duration=102.688s, table=0, n_packets=0, n_bytes=0, idle_age=102, priority=0,in_port=3 actions=output:4
 cookie=0x0, duration=108.369s, table=0, n_packets=0, n_bytes=0, idle_age=108, priority=0,in_port=1 actions=output:2
 cookie=0x0, duration=102.682s, table=0, n_packets=0, n_bytes=0, idle_age=102, priority=0,in_port=4 actions=output:3
 cookie=0x0, duration=108.365s, table=0, n_packets=0, n_bytes=0, idle_age=108, priority=0,in_port=2 actions=output:1
$ ./bin/patch_panel delete 0xabc 2 4
(trema runプロセス) Designated patch is not exist.
$ ./bin/patch_panel delete 0xabc 3 4
$ ./bin/trema dump_flows patch_panel
NXST_FLOW reply (xid=0x4):
 cookie=0x0, duration=232.328s, table=0, n_packets=0, n_bytes=0, idle_age=232, priority=0,in_port=1 actions=output:2
 cookie=0x0, duration=232.324s, table=0, n_packets=0, n_bytes=0, idle_age=232, priority=0,in_port=2 actions=output:1
```

##1. ポートのミラーリング
以下のように`パッチパネルのid，モニターポート，ミラーポート`を引数で与えて実行するpatch_panelのサブコマンド`create_mirror`を実装した．

``[使用例]$ ./bin/patch_panel create_mirror dpid monitor_port mirror_port``

ミラーポートにはモニターポートの送受信する内容が出力される．
###1.1 コード
####1.1.1 /lib/patch_panel.ｒｂへの追記内容
create_mirrorハンドラと，プライベートメソッドadd_mirror_entriesを追加
####1.1.2 /bin/patch_panelhへの追記内容
コマンドcreate_mirrorを定義
###1.2 動作確認
以下のpatch_panel.confで示すネットワーク構成で動作確認を行った．
```
vswitch('patch_panel') { datapath_id 0xabc }

vhost ('host1') { ip '192.168.0.1' }
vhost ('host2') { ip '192.168.0.2' }
vhost ('host3') {
 ip '192.168.0.3'
 promisc true }

link 'patch_panel', 'host1'
link 'patch_panel', 'host2'
link 'patch_panel', 'host3'
```

以下の手順で動作確認を行った
 1. host1をhost2でミラーリング
 2. host1とhost2をつなぐパッチを作成
 3. host2をhost3でミラーリング
 4. host１からhost2にパケットを送信
 5. host2からhost1にパケットを送信

実行結果は以下のようになり，host3でhost1とhost2の通信をミラーできていることを確認した．
```
(trema runプロセス) PatchPanel started.
$ bin/patch_panel create_mirror 0xabc 1 2
(trema runプロセス) Port1 is not patched.
$ ./bin/patch_panel create 0xabc 1 2
$ ./bin/patch_panel create_mirror 0xabc 2 3
$ ./bin/trema dump_flows patch_panel
NXST_FLOW reply (xid=0x4):
 cookie=0x0, duration=13.853s, table=0, n_packets=0, n_bytes=0, idle_age=13, priority=0,in_port=1 actions=output:2,output:3
 cookie=0x0, duration=13.858s, table=0, n_packets=0, n_bytes=0, idle_age=13, priority=0,in_port=2 actions=output:1,output:3
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
```


##2. パッチとポートミラーリングの一覧
以下のように実行するpatch_panelのサブコマンド``list``として実装した．

``[使用例]$ ./bin/patch_panel list dpid``

patch_panel.rbにメソッドlistを作成し，インスタンス変数@patchと@mirrorの中身を出力した．
###2.1 コード
####2.1.1 /lib/patch_panel．ｒｂへの追記内容
メソッドlistを作成
####2.1.2 /bin/patch_panelhへの追記内容
コマンドlistを定義
###2.2 動作確認
以下の入力を行った．

```
$ ./bin/patch_panel create 0xabc 1 2
$ ./bin/patch_panel create 0xabc 4 3
$ ./bin/patch_panel create_mirror 0xabc 2 5
$ ./bin/patch_panel list 0xabc
```

trema runプロセスにおける出力は以下となった．
```
PatchPanel started.
--------------------------------------------------
list of patch (dpid = 0xabc)
1 <---> 2
3 <---> 4
list of mirror (dpid = 0xabc)
2 ----> 5(mirror)
```
