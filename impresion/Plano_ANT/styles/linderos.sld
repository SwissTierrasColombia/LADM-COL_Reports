<?xml version="1.0" encoding="UTF-8"?><sld:StyledLayerDescriptor xmlns="http://www.opengis.net/sld" xmlns:sld="http://www.opengis.net/sld" xmlns:gml="http://www.opengis.net/gml" xmlns:ogc="http://www.opengis.net/ogc" version="1.0.0">
    <sld:UserLayer>
        <sld:LayerFeatureConstraints>
            <sld:FeatureTypeConstraint/>
        </sld:LayerFeatureConstraints>
        <sld:UserStyle>
            <sld:Name>linderos</sld:Name>
            <sld:FeatureTypeStyle>
                <sld:Name>group0</sld:Name>
                <sld:FeatureTypeName>Feature</sld:FeatureTypeName>
                <sld:SemanticTypeIdentifier>generic:geometry</sld:SemanticTypeIdentifier>
                <sld:SemanticTypeIdentifier>simple</sld:SemanticTypeIdentifier>
                <sld:Rule>
                    <sld:Name>default rule</sld:Name>
                    <sld:LineSymbolizer>
                        <sld:Stroke>
                            <sld:CssParameter name="stroke">#1B9E77</sld:CssParameter>
                            <sld:CssParameter name="stroke-width">1.5</sld:CssParameter>
                        </sld:Stroke>
                    </sld:LineSymbolizer>
                    <sld:PointSymbolizer>
                        <sld:Geometry>
                            <ogc:Function name="endPoint">
                                <ogc:PropertyName>geometry</ogc:PropertyName>
                            </ogc:Function>
                        </sld:Geometry>
                        <sld:Graphic>
                            <sld:Mark>
                                <sld:WellKnownName>shape://oarrow</sld:WellKnownName>
                                <sld:Stroke>
                                    <sld:CssParameter name="stroke">#1B9E77</sld:CssParameter>
                                </sld:Stroke>
                            </sld:Mark>
                            <sld:Size>12</sld:Size>
                            <sld:Rotation>
                                <ogc:Function name="endAngle">
                                    <ogc:PropertyName>geometry</ogc:PropertyName>
                                </ogc:Function>
                            </sld:Rotation>
                        </sld:Graphic>
                    </sld:PointSymbolizer>
                    <sld:PointSymbolizer>
                        <sld:Geometry>
                            <ogc:Function name="startPoint">
                                <ogc:PropertyName>geometry</ogc:PropertyName>
                            </ogc:Function>
                        </sld:Geometry>
                        <sld:Graphic>
                            <sld:Mark>
                                <sld:WellKnownName>shape://oarrow</sld:WellKnownName>
                                <sld:Stroke>
                                    <sld:CssParameter name="stroke">#1B9E77</sld:CssParameter>
                                </sld:Stroke>
                            </sld:Mark>
                            <sld:Size>12</sld:Size>
                            <sld:Rotation>
                                <ogc:Add>
                                    <ogc:Function name="startAngle">
                                        <ogc:PropertyName>geometry</ogc:PropertyName>
                                    </ogc:Function>
                                    <ogc:Literal>-180</ogc:Literal>
                                </ogc:Add>
                            </sld:Rotation>
                        </sld:Graphic>
                    </sld:PointSymbolizer>
                    <sld:TextSymbolizer>
                        <sld:Label>
                            <ogc:PropertyName>id</ogc:PropertyName>
                        </sld:Label>
                        <sld:Font>
                            <sld:CssParameter name="font-family">Arial</sld:CssParameter>
                            <sld:CssParameter name="font-size">6.0</sld:CssParameter>
                            <sld:CssParameter name="font-style">normal</sld:CssParameter>
                            <sld:CssParameter name="font-weight">bold</sld:CssParameter>
                        </sld:Font>
                        <sld:LabelPlacement>
                            <sld:LinePlacement>
                                <sld:PerpendicularOffset>6.0</sld:PerpendicularOffset>
                            </sld:LinePlacement>
                        </sld:LabelPlacement>
                        <sld:Halo>
                            <sld:Radius>0.4</sld:Radius>
                            <sld:Fill>
                                <sld:CssParameter name="fill">#FFFFFF</sld:CssParameter>
                            </sld:Fill>
                        </sld:Halo>
                        <sld:Fill>
                            <sld:CssParameter name="fill">#1B9E77</sld:CssParameter>
                        </sld:Fill>
                        <sld:VendorOption name="underlineText">true</sld:VendorOption>
                        <sld:VendorOption name="followLine">false</sld:VendorOption>
                    </sld:TextSymbolizer>
                </sld:Rule>
            </sld:FeatureTypeStyle>
        </sld:UserStyle>
    </sld:UserLayer>
</sld:StyledLayerDescriptor>

