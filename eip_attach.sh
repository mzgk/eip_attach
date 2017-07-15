#!/bin/bash

#---
#　自分にEIPがアタッチされていなければ、プール分からアタッチする。
# 起動時だと複数台でEIPを取り合うので、バッティングしてアタッチに失敗する場合がある。
# なので、cronを使って間隔で処理をする。
# eip_attached.txtの有無で判断するのは、無駄なcurlを減らすため。
#
# - /home/ec2-user/eip_attached.txtがあるか（初回は存在しない）
#   - Yes : EIPアタッチ済みなので終了
#   - No : 未アタッチなので次の処理へ
# - 自分にEIPがアタッチされているか（再検査）
#   - Yes : /ec2-user/home/eip_attached.txtを作成して終了
#   - No : 次へ
# - プールから１つ取得
#   - 取得したIPが他にアタッチされているか
#     - Yes : 次のプールIPへ
#     - No : 自分にアタッチして、/ec2-user/home/eip_attached.txtを作成して終了
#---

EIP_LIST=""
EIP_TXT="/home/ec2-user/eip_attached.txt"


# /home/ec2-user/eip_attached.txtが存在するか
if [ -f ${EIP_TXT} ]; then
  exit 0
fi


# リージョン
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')
export AWS_DEFAULT_REGION=${REGION}

# 自分のインスタンスIDを取得
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

# 自分のEIPを取得
EIP=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=${INSTANCE_ID}" --query "Addresses[].[AssociationId, AllocationId, PublicIp]" --output text)

# アタッチされている
if [ -n ${EIP} ]; then
  touch ${EIP_TXT}
  exit 0
fi
