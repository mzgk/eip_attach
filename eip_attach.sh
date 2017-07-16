#!/bin/bash

#---
#　自分にEIPがアタッチされていなければ、プール分からアタッチする。
# 起動時だと複数台でEIPを取り合うので、バッティングしてアタッチに失敗する場合がある。
# なので、cronを使って間隔で処理をする。
# アタッチ済みファイル（eip_attached.txt）の有無で判断するのは、無駄なcurlを減らすため。
#
# - アタッチ済みファイルがあるか（初回は存在しない）
#   - Yes : EIPアタッチ済みなので終了
#   - No : 未アタッチなので次の処理へ
# - 自分にEIPがアタッチされているか（再検査）
#   - Yes : アタッチ済みファイルを作成して終了
#   - No : 未アタッチなので次の処理へ
# - プール内から、他EC2にアタッチされていないEIPを全て取得する
# - 一つづつ取り出し、自身にアタッチ
#   - Yes : アタッチ済みファイルを作成し、終了
#   - No : 次のEIPへ
#---

EIP_POOL="eipalloc-8f4affeb eipalloc-bb3782df"
ATTACHED_TXT="/home/ec2-user/eip_attached.txt"


# アタッチ済みファイルが存在するか
if [ -f ${ATTACHED_TXT} ]; then
  echo "アタッチ済みファイルが存在"
  exit 0
fi


# リージョン
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')
export AWS_DEFAULT_REGION=${REGION}

# 自分のインスタンスIDを取得
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

# 自分のEIPを取得
EIP=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=${INSTANCE_ID}" --query "Addresses[].[PublicIp]" --output text)

# アタッチされている
if [ -n "$EIP" ]; then
  echo "EIPアタッチ済み"
  touch ${ATTACHED_TXT}
  exit 0
fi

echo "EIPなし"
echo ${EIP_POOL}

# プール内から、アタッチされていないEIPをすべて取得する
NOT_ATTACHED_EIPS=$(aws ec2 describe-addresses --allocation-ids ${EIP_POOL} --filter "Name=domain,Values=vpc" --output text | grep -v eipassoc- | awk '{print $2}')
echo ${NOT_ATTACHED_EIPS}

# 一つづつ取り出し、自身にアタッチさせる
for ALLOC_ID in ${NOT_ATTACHED_EIPS}
do
  echo ${ALLOC_ID}
  CMD="aws ec2 associate-address --instance-id ${INSTANCE_ID} --allocation-id ${ALLOC_ID}"
  $CMD
  STATUS=$?
  echo $STATUS

  # OKならアタッチファイルを作成し、終了
  if [ 0 = ${STATUS} ]; then
    EIP=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=${INSTANCE_ID}" --query "Addresses[].[PublicIp]" --output text)
    echo ${EIP}
    touch ${ATTACHED_TXT}
    exit 0
  fi
done

echo "EIPアタッチエラー"
exit 1
