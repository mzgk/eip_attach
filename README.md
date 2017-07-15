# なに？
- あらかじめプールされているEIP群の中から、自身にEIPをアタッチするシェルスクリプト

# 用途
- AutoScalingGroupを使って一斉に複数台が起動する場合、userdataで処理するとバッティングしてエラーになる
- なので、cronで一定間隔でこのシェルスクリプトを叩き、EIPがアタッチされているかを確認しアタッチさせる

# 処理フロー
*eip_attached.txtで判断するのは、無駄なcurlを減らすため*
- /home/ec2-user/eip_attached.txtがあるか（初回は存在しない）
  - Yes : EIPアタッチ済みなので終了
  - No : 未アタッチなので次の処理へ
- 自分にEIPがアタッチされているか（再検査）
  - Yes : /ec2-user/home/eip_attached.txtを作成して終了
  - No : 次へ
- プールから１つ取得
- 取得したIPが他にアタッチされているか
  - Yes : 次のプールIPへ
  - No : 自分にアタッチして、/ec2-user/home/eip_attached.txtを作成して終了
