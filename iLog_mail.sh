#!/bin/sh
# **********************************************************************
#  iLogscanner　結果メール送信シェルスクリプト
#     処理概要 : 引数1 のCSVを順次読み込みしてilogscannerの結果をメールする
#     更新履歴 : 2015/08/03 K.Urabe （新規作成）
#              : yyyy/mm/dd X.xxxxx (Modify)
# **********************************************************************
# 第１引数（CSVファイル）
CSVFILE=$1
# 前日日付を算出
W_DATE=`date --date '1 day ago' +"%Y/%m/%d"`
# 当日日付を算出
W_TODATE=`date  +%Y%m%d`
# チェックするディレクトリ
CHK_DIR="/var/lib/tomcat7/webapps/ROOT/ilog/"
# メール（TO）
MAIL_TO="foo@hoge.com"
# メール（FROM）
MAIL_FROM="var@hoge.com"
# メール本文
MAIL_TEXT="/tmp/ilog_mail.txt"
# ERRORフラグ　※Loop処理内で異常が発生した場合
ERROR_FLG="0"
# セキュリティ警告検出フラグ
SEC_FLG="0"

echo "#############################################"
echo "### iLogscanner メール送信スクリプト 開始     ###"
echo "#############################################"
echo "-- 開始時間：`date`"
# ============================================
# 引数確認
# ============================================
if [ ! -n "${CSVFILE}" ]; then
	echo "-- 終了時間：`date`"
	echo "*** ERROR：引数を設定してください ****"
	exit 2
fi

echo "各位\n"                                                  > ${MAIL_TEXT}
echo "お疲れ様です。"                                                       >> ${MAIL_TEXT}
echo "「iLogScanner - 解析結果レポート」のサマリーを送付します。\n"              >> ${MAIL_TEXT}
echo "■ MRTウェブサイト攻撃兆候検出結果（${W_DATE}分）"                        >> ${MAIL_TEXT}
echo "============================================="                       >> ${MAIL_TEXT}
# ============================================
# CSVファイルの順次読み込み
# ※ 第1カラムから重複行を削除して抜き出し
# ※ 「#」から始まる行はコメント行として読み飛ばす

# ============================================
for LINE in `cat ${CSVFILE} | grep -v ^# | cut -d ',' -f 1 |uniq`
do
	# XMLファイルを確認する。
	CHK_XML=${CHK_DIR}/xml/${LINE}/iLogScanner_${W_TODATE}.xml

	# XMLファイルの存在確認
	if [ ! -e ${CHK_XML} ]; then
		echo "*** ERROR:${CHK_XML} が存在しません ***"
		ERROR_FLG="1"
		continue
	fi

	SYS_NAME=${LINE}

	# xmllintコマンドによる抜出
	ATK_CNT=`xmllint --xpath "string(/AnalysisReport/Summary/AttackCountTotal)" ${CHK_XML}`
	MODSEC_CNT=`xmllint --xpath "string(/AnalysisReport/Summary/ModSecCountTotal)" ${CHK_XML}`

	# 検出が1件でもされればセキュリティ警告検出フラグを立てる
	if [ "${ATK_CNT}" -ne "0" ]; then
		SEC_FLG="1"
	fi

	# ModSecCountTotalがある場合とない場合でメッセージを変更する
	if [ ! -n "${MODSEC_CNT}" ]; then
		echo "${SYS_NAME} : 計 ${ATK_CNT} 件"                                                 >> ${MAIL_TEXT}
	else
		echo "${SYS_NAME} : 計 ${ATK_CNT} 件 (ModSecurityで検出・遮断した件数 ${MODSEC_CNT} 計)" >> ${MAIL_TEXT}
	fi

done

echo "============================================="               >> ${MAIL_TEXT}
echo "\n詳細については以下のURLにて確認してください。"                  >> ${MAIL_TEXT}
echo "■ URL"                                                       >> ${MAIL_TEXT}
echo "  http://hoge.xxx.local/InfraPortal/WebAttackResult\n" 　>> ${MAIL_TEXT}
echo "以上"                                                        >> ${MAIL_TEXT}
echo "よろしくお願います。"                                            >> ${MAIL_TEXT}

# ============================================
#  セキュリティ警告検出フラグの確認
# ============================================
if [ "${ATK_CNT}" -eq "0" ]; then
	MAIL_SUB="MRTウェブサイト攻撃兆候検出結果（${W_DATE}分）"
else
	MAIL_SUB="MRTウェブサイト攻撃兆候検出結果（${W_DATE}分）【異常検知】"
fi

echo "件名：${MAIL_SUB}"
echo "宛先：${MAIL_TO}"
echo "送信元：${MAIL_FROM}"
echo "本文："
cat ${MAIL_TEXT}
# ============================================
#  メール送信処理
# ============================================
# mail -s "${MAIL_SUB}" -aFROM:"${MAIL_FROM}" "${MAIL_TO}" < ${MAIL_TEXT}
# nkf -j ${MAIL_TEXT}| mail -s "`echo "${MAIL_SUB}" | nkf -j |nkf -M`" -aFROM:"${MAIL_FROM}" "${MAIL_TO}"
mail -s "`echo "${MAIL_SUB}" | nkf -j |nkf -M`" -aFROM:"${MAIL_FROM}" "${MAIL_TO}" < ${MAIL_TEXT}

# ============================================
#  エラーフラグの確認
# ============================================
if [ "${ERROR_FLG}" -ne "0" ]; then
	echo "-- 終了時間：`date`"
	echo "####### ERROR 処理異常終了 ########"

	exit 2
fi

echo "-- 終了時間：`date`"
echo "####### NORMAL END  #######"
exit 0
