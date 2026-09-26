-- Outdoor-only art direction. Original LightingPresets remain the stepped/garage reference.
return {
    ClockHours = {SevenAM=7, TenAM=10, Day=12, ThreePM=15, FivePM=17.5, EightPM=20, ClearNight=24, FourAM=28},
    Overrides = {
        SevenAM = {
            Lighting={Brightness=1.6, ExposureCompensation=-0.10},
            Atmosphere={Glare=1.2,Haze=2.2},
        },
        TenAM = {
            Lighting={Brightness=3,ExposureCompensation=0.05},
            Atmosphere={Glare=0.35,Haze=1.2},
        },
        Day = {
            Lighting={Brightness=3.5,ExposureCompensation=0.05},
        },
        ThreePM = {
            Lighting={Brightness=3,ExposureCompensation=0.05},
            Atmosphere={Glare=0.35,Haze=1.2},
        },
        FivePM = {
            Lighting={Brightness=1.5,ExposureCompensation=-0.15},
            Atmosphere={Glare=1.2,Haze=2.5},
        },
        EightPM = {
            Lighting={Brightness=1.2,ExposureCompensation=0},
            Atmosphere={Glare=0,Haze=3.1},
        },
        ClearNight = {
            Lighting={Brightness=1.3,ExposureCompensation=-0.05},
            Atmosphere={Glare=0,Haze=3.25},
        },
        FourAM = {
            Lighting={Brightness=1.2,ExposureCompensation=0},
            Atmosphere={Glare=0,Haze=3.1},
        },
    },
}
