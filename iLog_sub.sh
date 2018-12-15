#!/bin/sh
# **********************************************************************
#  iLogscanner　実行シェルスクリプト
#     処理概要 : 引数1 のCSVを順次読み込みしてilogscannerを実行する
#     更新履歴 : 2014/12/02 urabebebe （新規作成）
#              : yyyy/mm/dd X.xxxxx (Modify)
# **********************************************************************
# 第１引数（CSVファイル）
CSVFILE=$1
# iLogscanner.shの格納パス（フルパス）
ILOG_SH="/opt/iLogScanner/bin/iLogScanner.sh"
# 前日日付を算出
W_DATE=`date --date '1 day ago' +%Y%m%d`
# 当日日付を算出
W_TODATE=`date  +%Y%m%d`
# ERRORフラグ　※Loop処理内で異常が発生した場合
ERROR_FLG="0"

echo "#############################################"
echo "### Logscanner　実行シェルスクリプト 開始 ###"
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
# ============================================
# CSVファイルの順次読み込み
# ※ # から始まる行はコメント行として読み飛ばす
# ============================================
for LINE in `cat ${CSVFILE} | grep -v ^#`
do
	echo "=== LOOP START ==="
	# CSVの分解
	COL01=`echo ${LINE} | cut -d ',' -f 1`
	COL02=`echo ${LINE} | cut -d ',' -f 2`
	COL03=`echo ${LINE} | cut -d ',' -f 3`
	COL04=`echo ${LINE} | cut -d ',' -f 4`
	COL05=`echo ${LINE} | cut -d ',' -f 5`
	COL06=`echo ${LINE} | cut -d ',' -f 6`
	COL07=`echo ${LINE} | cut -d ',' -f 7`
	
	echo "→COL01=${COL01}  COL02=${COL02}  COL03=${COL03}  COL04=${COL04}  COL05=${COL05}  COL06=${COL06}"
	# ============================================
	# ６カラム目：出力フォルダの設定
	# ※ファイルの事前削除を行うので最初に実施
	# ============================================
	OUT_DIR=${COL06}

	if [ ! -d ${OUT_DIR} ]; then
		echo "*** ERROR:${OUT_DIR} が存在しません ***"
		ERROR_FLG="1"
		continue
	fi
	# ============================================
	# ７カラム目：出力形式タイプの指定
	# ※ファイルの事前削除を行うので最初に実施
	# ============================================
	REP_TYPE=${COL07}

	case "${REP_TYPE}" in
		"html"|"text"|"xml"|"all")
			echo "→出力タイプ指定OK"
			;;
		*)
			echo "*** ERROR:ファイル出力タイプ ${REP_TYPE} の指定が不正です"
			ERROR_FLG="1"
			continue
			;;
	esac
	# --------------------------------------------
	# 出力ファイルの事前削除 
	# --------------------------------------------
	rm -f ${OUT_DIR}/iLogScanner_${W_TODATE}*.${REP_TYPE}
	
	if [ "${ERROR_FLG}" -ne "0" ]; then
		echo "*** WARNING:${OUT_DIR}/iLogScanner_${W_TODATE}*.${REP_TYPE} の削除失敗しました ***"
		ERROR_FLG="1"
		# continue
	else
		echo "→削除完了"
	fi
	# ============================================
	# ２カラム目：ログ種別の確認
	# ============================================
	LOG_TYPE=${COL02}
	
	case "${LOG_TYPE}" in
		"apache"|"iis"|"iis_w3c"|"ssh"|"vsftpd"|"wu-ftpd")
			echo "→ログ種別指定OK"
			;;
		 *)
			echo "*** ERROR:${LOG_TYPE} の指定が不正です"
			ERROR_FLG="1"
			continue
			;;
	esac
	# ============================================
	# ３カラム目（appacelog）の設定
	# ※「YYYYYMMDD」の文字列があったら「前日日付」に置き換え
	# ============================================
	WK_ACC_LOG=`echo ${COL03}|sed -e "s/YYYYMMDD/${W_DATE}/"`
	
	if [ ! -e ${WK_ACC_LOG} ]; then
		echo "*** ERROR:${WK_ACC_LOG} が存在しません ***"
		ERROR_FLG="1"
		continue
	else
		echo "→${WK_ACC_LOG} 存在確認OK"
	fi

	echo "→WK_ACC_LOG=${WK_ACC_LOG}"
	
	# 拡張子の抜出
	echo "→拡張子=${WK_ACC_LOG##*.}"
	
	# 圧縮ファイルの場合、解凍する。	
	case "${WK_ACC_LOG##*.}" in
		"gz")
			# ファイル名のみ抜出
			ACC_FILE="${WK_ACC_LOG##*/}"
			
			echo "→ACC_FILE=${ACC_FILE}"

			cp -f ${WK_ACC_LOG} /tmp
			
			gunzip -f /tmp/${ACC_FILE}
			
			ACC_LOG=/tmp/`echo ${ACC_FILE}|sed -e "s/\.gz//"`
			;;
		*)
			ACC_LOG=${WK_ACC_LOG}
			;;
	esac
	
	echo "→ACC_LOG=${ACC_LOG}"
	# ============================================
	# ４カラム目（errorlog）の設定
	# ※iLogscanerの変数設定を行う関係上最後に判定
	# ============================================
	 if [ -n "${COL04}" ]; then
		# errorlog の設定あり
		# →errorlogの加工後に変数を設定する
		echo "→エラーファイルあり"
			
		WK_ERR_LOG=`echo ${COL04}|sed -e "s/YYYYMMDD/${W_DATE}/"`
		
		# 圧縮ファイルの場合、解凍する。	
		case "${WK_ERR_LOG##*.}" in
			"gz")
				# ファイル名のみ抜出
				ERR_FILE="${WK_ERR_LOG##*/}"
				
				echo "→ERR_FILE=${ERR_FILE}"
				
				cp -f ${WK_ERR_LOG} /tmp
				
				gunzip -f /tmp/${ERR_FILE}
			
				ERR_LOG=/tmp/`echo ${ERR_FILE}|sed -e "s/\.gz//"`
				;;
			*)
				ERR_LOG=${WK_ERR_LOG}
				;;
		esac
		
		echo "→ERR_LOG=${ERR_LOG}"
		# ============================================
		# ５カラム目（errorlogtype）の設定
		# ============================================
		ERRLOG_TYPE=${COL05}

		case "${ERRLOG_TYPE}" in
			"2.2"|"2.4")
				echo "→出力タイプ指定OK"
				;;
			*)
				echo "*** ERROR:ERRLOGタイプ ${ERRLOG_TYPE} の指定が不正です"
				ERROR_FLG="1"
				continue
				;;
		esac
		# →errlog設定でilogscannerの変数を作成
		WK_ARG="mode=cui logtype=${LOG_TYPE} level=detail accesslog=${ACC_LOG} errorlog=${ERR_LOG} errorlogtype=${ERRLOG_TYPE} reporttype=${REP_TYPE} outdir=${OUT_DIR} "
	else
		# errorlog の設定なし
		# →errlogなし設定でilogscannerの変数を作成
		echo "→エラーファイルなし"
		
		WK_ARG="mode=cui logtype=${LOG_TYPE} level=detail accesslog=${ACC_LOG} reporttype=${REP_TYPE} outdir=${OUT_DIR}"
        fi
	# ============================================
	# iLogscanner の実行
	# ============================================
	echo "→実行コマンド：${ILOG_SH} ${WK_ARG}"
	
	${ILOG_SH} ${WK_ARG}

	if [ "$?" -eq "0" ]; then
		echo "→${ILOG_SH} 正常終了"
	else
 		# 異常終了の場合でもERROR_FLGを立ててそのまま続行する
		echo "*** ERROR :${ILOG_SH} 異常終了 ***"
		ERROR_FLG="1"
		continue
	fi
	# ----------------------------------------------------------------------
	# 出力ファイルのリネーム
	# iLogScanner_YYYYMMDD_HHMMSS.hoge からiLogScanner_YYYYMMDD.hoge に変更
	# ----------------------------------------------------------------------
	mv ${OUT_DIR}/iLogScanner_${W_TODATE}*.${REP_TYPE}  ${OUT_DIR}/iLogScanner_${W_TODATE}.${REP_TYPE}
	
	if [ "${ERROR_FLG}" -ne "0" ]; then
		echo "*** WARNING:${OUT_DIR}/iLogScanner_${W_TODATE}*.${REP_TYPE} のリネームに失敗しました ***"
		ERROR_FLG="1"
		# continue
	else
		echo "→リネーム完了"
	fi
done
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
