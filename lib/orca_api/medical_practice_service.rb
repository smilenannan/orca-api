require_relative "service"

module OrcaApi
  # 診療行為を扱うサービスを表現したクラス
  #
  # @see http://cms-edit.orca.med.or.jp/receipt/tec/api/haori-overview.data/api21v03.pdf
  class MedicalPracticeService < Service
    # 選択項目が未指定であることを表現するクラス
    class UnselectedError < Result
      def ok?
        false
      end

      def message
        '選択項目が未指定です。'
      end
    end

    # 削除可能な剤の削除指示が未指定であることを表現するクラス
    class EmptyDeleteNumberInfoError < Result
      def ok?
        false
      end

      def message
        '削除可能な剤の削除指示が未指定です。'
      end
    end

    # デフォルト値の返却
    #
    # @param [Hash] params
    #   * Patient_ID (String)
    #     患者番号。必須。
    #   * Perform_Date (String)
    #     診療日付。YYYY-mm-dd形式。未設定はシステム日付。
    #   * Diagnosis_Information (Hash)
    #     * Department_Code (String)
    #       診療科。必須。
    #   * Medical_Information (Hash)
    #     * Doctors_Fee (String)
    #       診察料区分。
    #       01: 初診、02:再診、03:電話再診、09:診察料なし。
    #       設定がなければ、病名などから診察料を返却する。
    # @return [OrcaApi::Result]
    #   日レセからのレスポンス
    def get_default(params)
      req = params.merge(
        "Request_Number" => "00",
        "Karte_Uid" => orca_api.karte_uid
      )
      Result.new(orca_api.call("/api21/medicalmodv31", body: { "medicalv3req1" => req }))
    end

    # 診察料情報の取得
    #
    # @param params [Hash]
    #   診察料情報
    # @option params [String] "Patient_ID" 患者番号/20/必須
    # @option params [String] "Perform_Date" 診療日付/10/未設定はシステム日付
    # @option params [String] "Perform_Time" 診療時間/8/未使用
    # @option params [Hash] "Diagnosis_Information"
    #   送信内容
    #   * "Department_Code" (String) 診療科/2/必須
    #   * "Physician_Code" (String) ドクターコード/5
    #   * "HealthInsurance_Information" (Hash)
    #     保険情報/※１
    #     * "Insurance_Combination_Number" (String) 保険組合せ番号/4/指定があれば優先
    #     * "InsuranceProvider_Class" (String) 保険の種類/3
    #     * "InsuranceProvider_Number" (String) 保険者番号/8
    #     * "InsuranceProvider_WholeName" (String) 保険の制度名称/20
    #     * "HealthInsuredPerson_Symbol" (String) 記号/80
    #     * "HealthInsuredPerson_Number" (String) 番号/80
    #     * "HealthInsuredPerson_Continuation" (String) 継続区分/1
    #     * "HealthInsuredPerson_Assistance" (String) 補助区分/1
    #     * "RelationToInsuredPerson" (String) 本人家族区分/1
    #     * "HealthInsuredPerson_WholeName" (String) 被保険者名/100
    #     * "Certificate_StartDate" (String) 適用開始日/10
    #     * "Certificate_ExpiredDate" (String) 適用終了日/10
    #     * "PublicInsurance_Information" (Hash)
    #       公費情報　（４）/4
    #       * "PublicInsurance_Class" (String) 公費の種類/3
    #       * "PublicInsurance_Name" (String) 公費の制度名称/20
    #       * "PublicInsurer_Number" (String) 負担者番号/8
    #       * "PublicInsuredPerson_Number" (String) 受給者番号/20
    #       * "Certificate_IssuedDate" (String) 適用開始日/10
    #       * "Certificate_ExpiredDate" (String) 適用終了日/10
    #   * "Medical_Information" (Hash) 診療送信内容
    #     * "OffTime" (String) 時間外区分/1/外来時間外区分（０から８）とする（環境設定の外来時間外区分）
    #     * "Doctors_Fee" (String) 診察料区分/2/※２
    #     * "Medical_Class" (String) 診療種別区分/3/診察料コードの診療区分
    #     * "Medical_Class_Name" (String) 診療種別区分名称/40
    #     * "Medication_Info" (Hash)
    #       診療行為
    #       * "Medication_Code" (String) 診療コード/9/診察料コード　※３
    #       * "Medication_Name" (String) 名称/80
    #
    # @example
    #   params = {
    #     "Patient_ID" => patient_id,
    #     "Perform_Date" => "",
    #     "Perform_Time" => "",
    #     "Diagnosis_Information" => {
    #       "Department_Code" => "01",
    #       "Physician_Code" => "10001",
    #       "HealthInsurance_Information" => {
    #         "Insurance_Combination_Number" => insurance_combination_number,
    #       },
    #       "Medical_Information" => {
    #         "OffTime" => "0",
    #         "Doctors_Fee" => doctors_fee,
    #         "Medical_Class" => "",
    #         "Medical_Class_Name" => "",
    #         "Medication_Info" => {
    #           "Medication_Code" => "",
    #         }
    #       },
    #     },
    #   }
    #   result = medical_practice_service.get_examination_fee(params)
    #   if !result.ok?
    #     # エラー処理
    #   end
    #   medical_info = result.medical_information[0]["Medical_Info"] #=> 診察料情報
    #
    # @see http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api1
    # @see http://cms-edit.orca.med.or.jp/receipt/tec/api/haori-overview.data/api21v03.pdf （診療処理開始）
    # @see http://ftp.orca.med.or.jp/pub/data/receipt/tec/api/haori/HAORI_Layout/api_err.pdf
    def get_examination_fee(params)
      res = call_01_for_create(params)
      if !res.locked?
        unlock_for_create(res)
      end
      res
    end

    # 診療情報及び請求情報の取得
    # call_01_for_create
    # call_02
    # call_03
    # call_04
    # を順に呼び出す
    #
    # params["Medical_Select_Information"] = [
    #   { "Medical_Select" => "", "Select_Answer" => "" },
    # ]
    # params["Delete_Number_Info"] = [
    #   { "Delete_Number" => "" },
    # ]
    def calc_medical_practice_fee(params)
      res = if params["Invoice_Number"]
              call_01_for_update(params, "Modify")
            else
              call_01_for_create(params)
            end
      if !res.locked?
        locked_result = res
      end
      if !res.ok?
        return res
      end

      calc_medical_practice_fee_without_unlock(params, res)
    ensure
      unlock_for_create(locked_result)
    end

    # 診療行為の登録
    #
    # params["Ic_Code"]
    # params["Ic_Request_Code"]
    # params["Ic_All_Code"]
    # params["Cd_Information"]
    # params["Print_Information"]
    def create(params)
      res = if params["Invoice_Number"]
              call_01_for_update(params, "Modify")
            else
              call_01_for_create(params)
            end
      if !res.locked?
        locked_result = res
      end
      if !res.ok?
        return res
      end

      res = calc_medical_practice_fee_without_unlock(params, res)
      if !res.ok?
        return res
      end

      res = call_05(params, res)
      if res.ok?
        locked_result = nil
      end
      res
    ensure
      unlock_for_create(locked_result)
    end

    # 診療行為の取得
    def get(params)
      res = call_01_for_update(params, "Modify")
      if !res.locked?
        locked_result = res
      end
      res
    ensure
      unlock_for_update(locked_result)
    end

    # 診療行為の削除
    def destroy(params)
      res = call_01_for_update(params, "Delete")
      if !res.locked?
        locked_result = res
      end
      if res.api_result != "S30"
        return res
      end

      res = call_02_for_delete(res)
      if res.ok?
        locked_result = nil
      end
      res
    ensure
      unlock_for_update(locked_result)
    end

    alias update create

    # 薬剤併用禁忌チェック
    #
    # @param params [Hash]
    #   薬剤併用禁忌情報
    # @option params [String] "Patient_ID" 患者ID
    # @option params [String] "Perform_Month" 診療年月/7/未設定はシステム日付
    # @option params [String] "Check_Term" チェック期間/2/未設定はシステム管理の相互作用チェック期間
    # @option params [<Hash>] "Medical_Information"
    #   チェック薬剤情報
    #   * "Medication_Code" (String) 薬剤コード/9
    #   * "Medication_Name" (String) 薬剤名称
    #
    # @example
    #   params = {
    #     "Patient_ID" => patient_id,
    #     "Perform_Month" => "",
    #     "Check_Term" => "",
    #     "Medical_Information" => [
    #       {
    #         "Medication_Code" => "620002477"
    #       },
    #       {
    #         "Medication_Code" => "610422262"
    #       },
    #     ],
    #   }
    #   result = medical_practice_service.check_contraindication(params)
    #   if !result.ok?
    #     # エラー処理
    #   end
    #   result.perform_month #=> 診療年月
    #   result.patient_information #=> 患者情報
    #   result.medical_information #=> チェック薬剤情報
    #   result.symptom_information #=> 症状詳記内容
    #
    # @see http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api8
    # @see http://cms-edit.orca.med.or.jp/receipt/tec/api/haori-overview.data/api0214.pdf
    def check_contraindication(params)
      body = {
        "contraindication_checkreq" => {
          "Request_Number" => "01",
          "Karte_Uid" => orca_api.karte_uid,
        }.merge(params),
      }
      Result.new(orca_api.call("/api01rv2/contraindicationcheckv2", body: body))
    end

    private

    def calc_medical_practice_fee_without_unlock(params, get_examination_fee_result)
      res = call_02(params, get_examination_fee_result)
      if !res.ok?
        return res
      end

      res = call_03(res)
      while !res.ok?
        if res.body["Medical_Select_Flag"] == "True"
          if params["Medical_Select_Information"]
            answer = params["Medical_Select_Information"].find { |i|
              i["Medical_Select"] == res.body["Medical_Select_Information"]["Medical_Select"] && i["Select_Answer"]
            }
          end
          if answer
            res = call_03(res, answer)
          else
            return UnselectedError.new(res.raw)
          end
        else
          return res
        end
      end

      call_04(params, res)
    end

    # 診察料返却API（初回接続）
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api1
    # medicalv3req1
    def call_01_for_create(params)
      body = {
        "medicalv3req1" => {
          "Request_Number" => "01",
          "Karte_Uid" => orca_api.karte_uid,
          "Patient_ID" => params["Patient_ID"],
          "Perform_Date" => params["Perform_Date"],
          "Perform_Time" => params["Perform_Time"],
          "Orca_Uid" => "",
          "Diagnosis_Information" => params["Diagnosis_Information"],
        },
      }
      Result.new(orca_api.call("/api21/medicalmodv31", body: body))
    end

    # 診療内容基本チェックAPI
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api2
    # medicalv3req2
    def call_02(params, previous_result)
      res = previous_result
      res_body = res.body
      req = {
        "Request_Number" => res.response_number,
        "Karte_Uid" => res.karte_uid,
        "Patient_ID" => res.patient_information["Patient_ID"],
        "Perform_Date" => res_body["Perform_Date"],
        "Perform_Time" => res_body["Perform_Time"],
        "Orca_Uid" => res.orca_uid,
        "Diagnosis_Information" => {
          "Department_Code" => params["Diagnosis_Information"]["Department_Code"],
          "Physician_Code" => params["Diagnosis_Information"]["Physician_Code"],
          "Outside_Class" => params["Diagnosis_Information"]["Outside_Class"],
          "Medical_Information" => {
            "Medical_Info" => params["Diagnosis_Information"]["Medical_Information"]["Medical_Info"],
          },
          "HealthInsurance_Information" => res.patient_information["HealthInsurance_Information"],
          "Medical_OffTime" => res_body["Medical_OffTime"]
        }
      }
      if res_body["Invoice_Number"]
        req["Perform_Time"] = params["Perform_Time"]
        req["Invoice_Number"] = res_body["Invoice_Number"]
        req["Patient_Mode"] = "Modify"
        req["Diagnosis_Information"]["HealthInsurance_Information"] =
          params["Diagnosis_Information"]["HealthInsurance_Information"]
        req["Diagnosis_Information"]["Medical_OffTime"] = params["Diagnosis_Information"]["Medical_Information"]["OffTime"]
      end
      Result.new(orca_api.call("/api21/medicalmodv32", body: { "medicalv3req2" => req }))
    end

    # 診療確認API
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api3
    # medicalv3req2
    def call_03(previous_result, answer = nil)
      res = previous_result
      res_body = res.body
      req = {
        "Request_Number" => res.response_number,
        "Karte_Uid" => res.karte_uid,
        "Patient_ID" => res.patient_information["Patient_ID"],
        "Perform_Date" => res_body["Perform_Date"],
        "Perform_Time" => res_body["Perform_Time"],
        "Orca_Uid" => res.orca_uid,
        "Diagnosis_Information" => {
          "Physician_Code" => res_body["Physician_Code"],
        },
      }
      if res.body["Invoice_Number"]
        req["Patient_Mode"] = "Modify"
        req["Invoice_Number"] = res.invoice_number
      end
      if answer
        req["Select_Answer"] = answer["Select_Answer"]
      end
      Result.new(orca_api.call("/api21/medicalmodv32", body: { "medicalv3req2" => req }))
    end

    # 診療確認・請求確認API
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api4
    # medicalv3req3
    def call_04(params, previous_result)
      res = previous_result

      can_delete = res.medical_information["Medical_Info"].any? { |i| i["Medical_Delete_Number"] }
      if can_delete && !params["Delete_Number_Info"]
        return EmptyDeleteNumberInfoError.new(res.raw)
      end

      req = {
        "Request_Number" => res.response_number,
        "Karte_Uid" => res.karte_uid,
        "Base_Date" => params["Base_Date"],
        "Patient_ID" => res.patient_information["Patient_ID"],
        "Perform_Date" => res.body["Perform_Date"],
        "Orca_Uid" => res.orca_uid,
        "Medical_Mode" => (can_delete && params["Delete_Number_Info"] ? "1" : nil),
        "Delete_Number_Info" => params["Delete_Number_Info"],
        "Ic_Code" => params["Ic_Code"],
        "Ic_Request_Code" => params["Ic_Request_Code"],
        "Ic_All_Code" => params["Ic_All_Code"],
        "Cd_Information" => params["Cd_Information"],
        "Print_Information" => params["Print_Information"],
      }
      if params["Invoice_Number"]
        req["Patient_Mode"] = "Modify"
      end
      Result.new(orca_api.call("/api21/medicalmodv33", body: { "medicalv3req3" => req }))
    end

    # 診療登録API
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api5
    # medicalv3req3
    def call_05(params, previous_result)
      res = previous_result
      req = {
        "Request_Number" => res.response_number,
        "Karte_Uid" => res.karte_uid,
        "Base_Date" => params["Base_Date"],
        "Patient_ID" => res.patient_information["Patient_ID"],
        "Perform_Date" => res.body["Perform_Date"],
        "Orca_Uid" => res.orca_uid,
        "Ic_Code" => params["Ic_Code"],
        "Ic_Request_Code" => params["Ic_Request_Code"],
        "Ic_All_Code" => params["Ic_All_Code"],
        "Cd_Information" => params["Cd_Information"],
        "Print_Information" => params["Print_Information"],
      }
      if params["Invoice_Number"]
        req["Patient_Mode"] = "Modify"
      end
      Result.new(orca_api.call("/api21/medicalmodv33", body: { "medicalv3req3" => req }))
    end

    # 診療行為訂正処理
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api7
    # medicalv3req4
    def call_01_for_update(params, patient_mode)
      body = {
        "medicalv3req4" => {
          "Request_Number" => "01",
          "Karte_Uid" => orca_api.karte_uid,
          "Orca_Uid" => "",
          "Patient_ID" => params["Patient_ID"],
          "Perform_Date" => params["Perform_Date"],
          "Patient_Mode" => patient_mode,
          "Invoice_Number" => params["Invoice_Number"],
          "Department_Code" => params["Department_Code"],
          "Insurance_Combination_Number" => params["Insurance_Combination_Number"],
          "Sequential_Number" => params["Sequential_Number"],
        },
      }
      Result.new(orca_api.call("/api21/medicalmodv34", body: body))
    end

    # 診療行為削除処理
    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api6
    # medicalv3req4
    def call_02_for_delete(previous_result)
      res = previous_result
      body = {
        "medicalv3req4" => {
          "Request_Number" => res.response_number,
          "Karte_Uid" => orca_api.karte_uid,
          "Orca_Uid" => res.orca_uid,
          "Patient_ID" => res.patient_information["Patient_ID"],
          "Perform_Date" => res.perform_date,
          "Patient_Mode" => "Delete",
          "Invoice_Number" => res.invoice_number,
          "Department_Code" => res.department_code,
          "Insurance_Combination_Number" => res.health_insurance_information["Insurance_Combination_Number"],
          "Sequential_Number" => res.sequential_number,
          "Select_Answer" => "Ok",
        },
      }
      Result.new(orca_api.call("/api21/medicalmodv34", body: body))
    end

    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api1
    # http://cms-edit.orca.med.or.jp/receipt/tec/api/haori-overview.data/api21v03.pdf
    # medicalv3req1
    def unlock_for_create(locked_result)
      if locked_result && locked_result.respond_to?(:orca_uid)
        body = {
          "medicalv3req1" => {
            "Request_Number" => "99",
            "Karte_Uid" => orca_api.karte_uid,
            "Perform_Date" => locked_result.body["Perform_Date"],
            "Orca_Uid" => locked_result.orca_uid,
          },
        }
        orca_api.call("/api21/medicalmodv31", body: body)
        # TODO: エラー処理
      end
    end

    # http://cms-edit.orca.med.or.jp/_admin/preview_revision/16921#api6
    # http://cms-edit.orca.med.or.jp/receipt/tec/api/haori-overview.data/api21v03.pdf
    # medicalv3req4
    def unlock_for_update(locked_result)
      if locked_result && locked_result.respond_to?(:orca_uid)
        body = {
          "medicalv3req4" => {
            "Request_Number" => "99",
            "Karte_Uid" => orca_api.karte_uid,
            "Patient_ID" => locked_result.patient_information["Patient_ID"],
            "Perform_Date" => locked_result.perform_date,
            "Orca_Uid" => locked_result.orca_uid,
          },
        }
        orca_api.call("/api21/medicalmodv34", body: body)
        # TODO: エラー処理
      end
    end
  end
end
