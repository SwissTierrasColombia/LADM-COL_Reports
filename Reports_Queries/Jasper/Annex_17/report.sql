SELECT 
  lc_predio.matricula_inmobiliaria
  ,lc_predio.nupre
  ,lc_predio.numero_predial
  ,lc_predio.nombre
  ,departamento 
  ,municipio 
  --,zona 
  ,numero_predial_anterior
  ,area_terreno
  ,st_x(st_transform(st_centroid(geometria),4326)) as x
  ,st_y(st_transform(st_centroid(geometria),4326)) as y
  ,lc_predio.espacio_de_nombres || lc_predio.local_id as codigo
FROM 
  ladm_lev_cat_v1.lc_terreno   --parametrizar schema $P!{datasetName}
  LEFT JOIN ladm_lev_cat_v1.col_uebaunit ON lc_terreno.t_id = col_uebaunit.ue_lc_terreno --parametrizar schema $P!{datasetName}
  LEFT JOIN ladm_lev_cat_v1.lc_predio ON lc_predio.t_id = col_uebaunit.baunit  --parametrizar schema $P!{datasetName}
WHERE lc_terreno.t_id =  1522 -- parametrizar $P{id}