class CreateAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :analyses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename
      t.text :original_text
      t.string :status
      t.text :orthography_json
      t.text :writing_suggestions_json
      t.text :legal_insights_json
      t.string :analysis_mode

      t.timestamps
    end
  end
end
