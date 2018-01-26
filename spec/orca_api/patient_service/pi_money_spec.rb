require "spec_helper"
require_relative "../shared_examples"

RSpec.describe OrcaApi::PatientService::PiMoney, orca_api_mock: true do
  let(:service) { described_class.new(orca_api) }

  describe "#target_of" do
    context "正常系" do
      it "公費負担額登録対象の公費一覧を取得できること" do
        expect_data = [
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "01",
                "Karte_Uid" => orca_api.karte_uid,
                "Patient_Information" => {
                  "Patient_ID" => "3",
                }
              }
            },
            result: "orca12_patientmodv35_01.json",
          },
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "99",
                "Karte_Uid" => '`prev.karte_uid`',
                "Orca_Uid" => "`prev.orca_uid`",
              }
            },
            result: "orca12_patientmodv35_99.json",
          },
        ]

        expect_orca_api_call(expect_data, binding)

        result = service.target_of(3)

        expect(result.ok?).to be true
      end
    end

    context "異常系" do
      it "患者番号に該当する患者が存在しない場合、ロック解除を行わないこと" do
        expect_data = [
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "01",
                "Karte_Uid" => orca_api.karte_uid,
                "Patient_Information" => {
                  "Patient_ID" => "999999",
                }
              }
            },
            result: "orca12_patientmodv35_01_E10.json",
          },
        ]

        expect_orca_api_call(expect_data, binding)

        result = service.target_of(999999)

        expect(result.ok?).to be false
      end
    end
  end

  describe "#get" do
    context "正常系" do
      it "公費負担額一覧を取得できること" do
        expect_data = [
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "01",
                "Karte_Uid" => orca_api.karte_uid,
                "Patient_Information" => {
                  "Patient_ID" => "3",
                }
              }
            },
            result: "orca12_patientmodv35_01.json",
          },
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "02",
                "Karte_Uid" => '`prev.karte_uid`',
                "Orca_Uid" => "`prev.orca_uid`",
                "Patient_Information" => "`prev.patient_information`",
                "PublicInsurance_Information" => {
                  "PublicInsurance_Id" => "4",
                },
              }
            },
            result: "orca12_patientmodv35_02.json",
          },
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "99",
                "Karte_Uid" => '`prev.karte_uid`',
                "Orca_Uid" => "`prev.orca_uid`",
              }
            },
            result: "orca12_patientmodv35_99.json",
          },
        ]

        expect_orca_api_call(expect_data, binding)

        result = service.get(3, 4)

        expect(result.ok?).to be true
      end
    end

    context "異常系" do
      it "患者番号に該当する患者が存在しない場合、ロック解除を行わないこと" do
        expect_data = [
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "01",
                "Karte_Uid" => orca_api.karte_uid,
                "Patient_Information" => {
                  "Patient_ID" => "999999",
                }
              }
            },
            result: "orca12_patientmodv35_01_E10.json",
          },
        ]

        expect_orca_api_call(expect_data, binding)

        result = service.get(999999, 4)

        expect(result.ok?).to be false
      end

      it "公費IDに該当する公費が存在しない場合、ロック解除を行うこと" do
        expect_data = [
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "01",
                "Karte_Uid" => orca_api.karte_uid,
                "Patient_Information" => {
                  "Patient_ID" => "3",
                }
              }
            },
            result: "orca12_patientmodv35_01.json",
          },
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "02",
                "Karte_Uid" => '`prev.karte_uid`',
                "Orca_Uid" => "`prev.orca_uid`",
                "Patient_Information" => "`prev.patient_information`",
                "PublicInsurance_Information" => {
                  "PublicInsurance_Id" => "5",
                },
              }
            },
            result: "orca12_patientmodv35_02_E32.json",
          },
          {
            path: "/orca12/patientmodv35",
            body: {
              "=patientmodv3req5" => {
                "Request_Number" => "99",
                "Karte_Uid" => '`prev.karte_uid`',
                "Orca_Uid" => "`prev.orca_uid`",
              }
            },
            result: "orca12_patientmodv35_99.json",
          },
        ]

        expect_orca_api_call(expect_data, binding)

        result = service.get(3, 5)

        expect(result.ok?).to be false
      end
    end
  end
end
