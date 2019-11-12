SELECT 
  op_predio.matricula_inmobiliaria 
  ,op_predio.nupre 
  ,op_predio.numero_predial
  ,op_predio.nombre 
  ,departamento 
  ,municipio 
  --,zona 
  ,numero_predial_anterior
  ,area_terreno
  ,st_x(st_transform(st_centroid(geometria),4326)) as x
  ,st_y(st_transform(st_centroid(geometria),4326)) as y
  ,op_predio.espacio_de_nombres || op_predio.local_id as codigo
FROM 
  ladmcol_2_9_6.op_terreno   --parametrizar schema $P!{datasetName}
  LEFT JOIN ladmcol_2_9_6.col_uebaunit ON op_terreno.t_id = col_uebaunit.ue_op_terreno --parametrizar schema $P!{datasetName}
  LEFT JOIN ladmcol_2_9_6.op_predio ON op_predio.t_id = col_uebaunit.baunit  --parametrizar schema $P!{datasetName}
WHERE op_terreno.t_id =  1522 -- parametrizar $P{id}