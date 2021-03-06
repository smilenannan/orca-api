require_relative "income_common"

module OrcaApi
  class PatientService < Service
    # 低所得者１情報（年金履歴）を扱うサービス
    #
    # @see http://cms-edit.orca.med.or.jp/receipt/tec/api/haori_patientmod.data/api12v034.pdf
    # @see http://cms-edit.orca.med.or.jp/receipt/tec/api/haori_patientmod.data/api12v034_err.pdf
    class Pension < IncomeCommon
    end
  end
end
