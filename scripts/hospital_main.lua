-- Paksa reload kedua module setiap kali hospital_main dijalankan.
-- Ini penting agar callback ter-register ulang setelah reloadScripts()
-- karena engine menghapus semua callback saat reload, tapi global Lua tetap hidup.
package.loaded["malady_rng.plua"] = nil
package.loaded["malady_rng"] = nil
package.loaded["hospital"] = nil
package.loaded["vile_vial"] = nil

local okProtected, protectedModule = pcall(require, "malady_rng.plua")
if okProtected then
	MaladySystem = protectedModule
else
	MaladySystem = require("malady_rng")
end
HospitalSystem = require("hospital")
VileVialSystem = require("vile_vial")

