// Self-contained fixture generator for the macOS Swift parity tests.
//
// Copies the prayer-time and Hijri-date math VERBATIM from the Java reference
// app (src/main/java/uz/khoshimjonov/service/{SalahTimesCalculator,HijriDate}.java)
// so we can compile/run with plain `javac` + `java` — no Maven, no Lombok.
//
// If the Java reference math ever changes, re-copy the corresponding methods
// here and regenerate fixtures. The Swift `CalculationParityTests` will catch
// any drift.

import java.io.IOException;
import java.nio.file.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class FixtureGenerator {

    // ============================== ENUMS ================================

    enum CalculationMethod {
        MWL("Muslim World League", 18.0, 17.0, 0),
        ISNA("Islamic Society of North America", 15.0, 15.0, 0),
        EGYPT("Egyptian General Authority of Survey", 19.5, 17.5, 0),
        MAKKAH("Umm Al-Qura University, Makkah", 18.5, 0, 90),
        KARACHI("University of Islamic Sciences, Karachi", 18.0, 18.0, 0),
        TEHRAN("Institute of Geophysics, University of Tehran", 17.7, 14.0, 0),
        JAFARI("Shia Ithna-Ashari, Leva Institute, Qum", 16.0, 14.0, 0),
        SINGAPORE("Singapore Islamic Religious Council", 20.0, 18.0, 0),
        TURKEY("Diyanet İşleri Başkanlığı, Turkey", 18.0, 17.0, 0),
        DUBAI("Gulf Region", 18.2, 18.2, 0),
        KUWAIT("Kuwait", 18.0, 17.5, 0),
        QATAR("Qatar", 18.0, 0, 90),
        RUSSIA("Spiritual Administration of Muslims of Russia", 16.0, 15.0, 0),
        FRANCE("Union of Islamic Organizations of France", 12.0, 12.0, 0);

        final String displayName;
        final double fajrAngle, ishaAngle;
        final int ishaMinutes;
        CalculationMethod(String n, double f, double i, int im) {
            this.displayName = n; this.fajrAngle = f; this.ishaAngle = i; this.ishaMinutes = im;
        }
    }

    enum AsrMethod {
        SHAFII(1), HANAFI(2);
        final int shadowRatio;
        AsrMethod(int s) { this.shadowRatio = s; }
    }

    enum HighLatMethod { NONE, NIGHT_MIDDLE, ONE_SEVENTH, ANGLE_BASED }

    // ============================ CALCULATOR =============================

    static final double DEG_TO_RAD = Math.PI / 180.0;
    static final double RAD_TO_DEG = 180.0 / Math.PI;
    static final int IMSAK = 0, FAJR = 1, SUNRISE = 2, DHUHR = 3,
                     ASR = 4, MAGHRIB = 5, ISHA = 6, MIDNIGHT = 7, LAST_THIRD = 8;

    static double[] computePrayerTimes(double jd, double tzOffset,
                                       double lat, double lon, double elevation,
                                       CalculationMethod method, AsrMethod asr,
                                       HighLatMethod hl, double imsakMinutes) {
        double[] times = new double[9];
        double decl = sunDeclination(jd);
        double eqt = equationOfTime(jd);
        double dhuhr = 12.0 + tzOffset - lon / 15.0 - eqt;
        double riseSetAngle = 0.833 + 0.0347 * Math.sqrt(elevation);

        double sunriseHA = hourAngle(riseSetAngle, decl, lat);
        double fajrHA = hourAngle(method.fajrAngle, decl, lat);
        double asrHA = asrHourAngle(decl, lat, asr);
        double ishaHA = hourAngle(method.ishaAngle, decl, lat);

        times[DHUHR] = dhuhr;
        times[SUNRISE] = dhuhr - sunriseHA;
        times[MAGHRIB] = dhuhr + sunriseHA;
        times[FAJR] = dhuhr - fajrHA;
        times[ASR] = dhuhr + asrHA;

        if (method.ishaMinutes > 0) {
            times[ISHA] = times[MAGHRIB] + method.ishaMinutes / 60.0;
        } else {
            times[ISHA] = dhuhr + ishaHA;
        }
        times[IMSAK] = times[FAJR] - imsakMinutes / 60.0;

        times = adjustHighLatitude(times, dhuhr, lat, method, hl, imsakMinutes);

        double nextDecl = sunDeclination(jd + 1);
        double nextEqt = equationOfTime(jd + 1);
        double nextDhuhr = 12.0 + tzOffset - lon / 15.0 - nextEqt;
        double nextFajrHA = hourAngle(method.fajrAngle, nextDecl, lat);
        double nextFajr = nextDhuhr - nextFajrHA;

        double nightDuration = (nextFajr + 24.0) - times[MAGHRIB];
        if (nightDuration > 24.0) nightDuration -= 24.0;

        times[MIDNIGHT] = times[MAGHRIB] + nightDuration / 2.0;
        times[LAST_THIRD] = times[MAGHRIB] + nightDuration * 2.0 / 3.0;

        return times;
    }

    static double hourAngle(double angle, double decl, double lat) {
        double latRad = lat * DEG_TO_RAD;
        double declRad = decl * DEG_TO_RAD;
        double angleRad = angle * DEG_TO_RAD;
        double cosHA = (-Math.sin(angleRad) - Math.sin(latRad) * Math.sin(declRad))
                / (Math.cos(latRad) * Math.cos(declRad));
        if (cosHA < -1.0 || cosHA > 1.0) return Double.NaN;
        return Math.acos(cosHA) * RAD_TO_DEG / 15.0;
    }

    static double asrHourAngle(double decl, double lat, AsrMethod asr) {
        double latRad = lat * DEG_TO_RAD;
        double declRad = decl * DEG_TO_RAD;
        double shadowAngle = Math.atan(1.0 / (asr.shadowRatio + Math.tan(Math.abs(latRad - declRad))));
        double cosHA = (Math.sin(shadowAngle) - Math.sin(latRad) * Math.sin(declRad))
                / (Math.cos(latRad) * Math.cos(declRad));
        if (cosHA < -1.0 || cosHA > 1.0) return Double.NaN;
        return Math.acos(cosHA) * RAD_TO_DEG / 15.0;
    }

    static double sunDeclination(double jd) {
        double D = jd - 2451545.0;
        double g = norm360(357.529 + 0.98560028 * D);
        double q = norm360(280.459 + 0.98564736 * D);
        double L = norm360(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g));
        double e = 23.439 - 0.00000036 * D;
        return darcsin(dsin(e) * dsin(L));
    }

    static double equationOfTime(double jd) {
        double D = jd - 2451545.0;
        double g = norm360(357.529 + 0.98560028 * D);
        double q = norm360(280.459 + 0.98564736 * D);
        double L = norm360(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g));
        double e = 23.439 - 0.00000036 * D;
        double RA = darctan2(dcos(e) * dsin(L), dcos(L)) / 15.0;
        return q / 15.0 - normHour(RA);
    }

    static double[] adjustHighLatitude(double[] times, double dhuhr, double lat,
                                       CalculationMethod method, HighLatMethod hl,
                                       double imsakMinutes) {
        if (hl == HighLatMethod.NONE) return times;
        double sunrise = times[SUNRISE], sunset = times[MAGHRIB];
        double nightTime = 24.0 - (sunset - sunrise);
        double fajrDiff = nightPortion(method.fajrAngle, hl) * nightTime;
        if (Double.isNaN(times[FAJR]) || (sunrise - times[FAJR]) > fajrDiff) {
            times[FAJR] = sunrise - fajrDiff;
            times[IMSAK] = times[FAJR] - imsakMinutes / 60.0;
        }
        double ishaAngle = method.ishaMinutes > 0 ? 18.0 : method.ishaAngle;
        double ishaDiff = nightPortion(ishaAngle, hl) * nightTime;
        if (Double.isNaN(times[ISHA]) || (times[ISHA] - sunset) > ishaDiff) {
            times[ISHA] = sunset + ishaDiff;
        }
        return times;
    }

    static double nightPortion(double angle, HighLatMethod hl) {
        switch (hl) {
            case NIGHT_MIDDLE: return 0.5;
            case ONE_SEVENTH: return 1.0 / 7.0;
            case ANGLE_BASED: return angle / 60.0;
            default: return 0;
        }
    }

    static double julianDate(int year, int month, int day) {
        if (month <= 2) { year -= 1; month += 12; }
        int A = year / 100;
        int B = 2 - A + A / 4;
        return Math.floor(365.25 * (year + 4716))
                + Math.floor(30.6001 * (month + 1))
                + day + B - 1524.5;
    }

    static double dsin(double d) { return Math.sin(d * DEG_TO_RAD); }
    static double dcos(double d) { return Math.cos(d * DEG_TO_RAD); }
    static double darcsin(double x) { return Math.asin(x) * RAD_TO_DEG; }
    static double darctan2(double y, double x) { return Math.atan2(y, x) * RAD_TO_DEG; }
    static double normHour(double h) { h = h % 24.0; return h < 0 ? h + 24.0 : h; }
    static double norm360(double d) { d = d % 360.0; return d < 0 ? d + 360.0 : d; }

    // ========================== CALC ENTRY POINT ==========================

    static class TimesResult {
        final LocalDate date;
        final LocalTime[] times = new LocalTime[9];
        TimesResult(LocalDate d) { this.date = d; }
    }

    static TimesResult calculate(LocalDate date, double lat, double lon, double elev,
                                 ZoneId zone, CalculationMethod method, AsrMethod asr,
                                 HighLatMethod hl, double imsakMinutes, int[] adjustments) {
        ZonedDateTime zdt = date.atStartOfDay(zone);
        double tzOffset = zdt.getOffset().getTotalSeconds() / 3600.0;
        double jd = julianDate(date.getYear(), date.getMonthValue(), date.getDayOfMonth());
        double[] times = computePrayerTimes(jd, tzOffset, lat, lon, elev, method, asr, hl, imsakMinutes);
        for (int i = 0; i < Math.min(adjustments.length, 7); i++) {
            times[i] += adjustments[i] / 60.0;
        }
        for (int i = 0; i < times.length; i++) times[i] = normHour(times[i]);
        TimesResult r = new TimesResult(date);
        for (int i = 0; i < 9; i++) r.times[i] = toTime(times[i]);
        return r;
    }

    static LocalTime toTime(double hours) {
        if (Double.isNaN(hours) || Double.isInfinite(hours)) return null;
        hours = hours % 24;
        if (hours < 0) hours += 24;
        int totalSeconds = (int) Math.round(hours * 3600);
        if (totalSeconds >= 86400) totalSeconds = totalSeconds % 86400;
        int h = totalSeconds / 3600, m = (totalSeconds % 3600) / 60, s = totalSeconds % 60;
        return LocalTime.of(h, m, s);
    }

    // ============================== HIJRI ================================

    static final double HIJRI_EPOCH = 1948439.5;
    static final int[] LEAP_YEARS_IN_CYCLE = {2,5,7,10,13,16,18,21,24,26,29};

    static boolean isLeapInCycle(int y) {
        for (int ly : LEAP_YEARS_IN_CYCLE) if (ly == y) return true;
        return false;
    }
    static boolean isLeap(int year) {
        int p = ((year - 1) % 30) + 1;
        return isLeapInCycle(p);
    }
    static int daysInMonth(int year, int month) {
        if (month % 2 == 1) return 30;
        if (month == 12 && isLeap(year)) return 30;
        return 29;
    }

    static int[] gregorianToHijri(int gy, int gm, int gd) {
        double jd = julianDate(gy, gm, gd);
        jd = Math.floor(jd) + 0.5;
        double days = jd - HIJRI_EPOCH;
        int cycles = (int) Math.floor(days / 10631.0);
        double remaining = days - cycles * 10631.0;
        int yearInCycle = 0;
        double dayCount = 0;
        for (int y = 1; y <= 30; y++) {
            int dpy = isLeapInCycle(y) ? 355 : 354;
            if (dayCount + dpy > remaining) {
                yearInCycle = y;
                remaining -= dayCount;
                break;
            }
            dayCount += dpy;
            if (y == 30) { yearInCycle = 30; remaining -= dayCount; }
        }
        int year = cycles * 30 + yearInCycle;
        int month = 1;
        int dayOfYear = (int) Math.floor(remaining) + 1;
        for (int m = 1; m <= 12; m++) {
            int dim = daysInMonth(year, m);
            if (dayOfYear <= dim) { month = m; break; }
            dayOfYear -= dim;
            month = m + 1;
        }
        int day = dayOfYear;
        if (month > 12) { month = 12; day = daysInMonth(year, 12); }
        if (day < 1) day = 1;
        if (day > 30) day = 30;
        return new int[]{year, month, day};
    }

    // =============================== MAIN ================================

    public static void main(String[] args) throws IOException {
        String outDir = args.length > 0 ? args[0] : ".";
        StringBuilder sb = new StringBuilder();
        sb.append("[\n");
        boolean first = true;

        // Test cases: a grid that exercises every code path.
        // Locations from -65° lat (high south) to +66° (high north),
        // all 14 methods × both schools, on 4 dates including a Ramadan day.
        double[][] locs = {
            {41.37, 69.26, 460, 0},   // Tashkent, ID 0
            {21.42, 39.83, 277, 1},   // Makkah
            {3.14, 101.69, 50, 2},    // Kuala Lumpur (equator)
            {51.51, -0.13, 30, 3},    // London
            {59.94, 30.31, 10, 4},    // St Petersburg (high lat)
            {66.50, 25.72, 100, 5},   // Rovaniemi (Arctic Circle)
            {-33.87, 151.21, 30, 6},  // Sydney (south)
            {-65.30, -64.20, 50, 7}   // Antarctic Pen.
        };
        String[] zones = {
            "Asia/Tashkent","Asia/Riyadh","Asia/Kuala_Lumpur","Europe/London",
            "Europe/Moscow","Europe/Helsinki","Australia/Sydney","Antarctica/Palmer"
        };
        LocalDate[] dates = {
            LocalDate.of(2025,  3, 21),  // equinox
            LocalDate.of(2025,  6, 21),  // solstice (problematic at high lat)
            LocalDate.of(2025, 12,  8),  // Java app's example date
            LocalDate.of(2026,  3, 18)   // mid Ramadan 1447
        };
        HighLatMethod hl = HighLatMethod.ANGLE_BASED;
        double imsakMinutes = 10.0;
        int[] noAdj = new int[9];

        for (int li = 0; li < locs.length; li++) {
            double[] loc = locs[li];
            ZoneId zone = ZoneId.of(zones[li]);
            for (CalculationMethod m : CalculationMethod.values()) {
                for (AsrMethod a : AsrMethod.values()) {
                    for (LocalDate d : dates) {
                        TimesResult r = calculate(d, loc[0], loc[1], loc[2],
                                                  zone, m, a, hl, imsakMinutes, noAdj);
                        if (!first) sb.append(",\n");
                        first = false;
                        sb.append("  {\"loc\":").append((int) loc[3])
                          .append(",\"lat\":").append(loc[0])
                          .append(",\"lon\":").append(loc[1])
                          .append(",\"elev\":").append(loc[2])
                          .append(",\"zone\":\"").append(zones[li]).append('"')
                          .append(",\"method\":\"").append(m.name()).append('"')
                          .append(",\"school\":\"").append(a.name()).append('"')
                          .append(",\"hl\":\"").append(hl.name()).append('"')
                          .append(",\"imsakMinutes\":").append(imsakMinutes)
                          .append(",\"date\":\"").append(d).append('"');
                        String[] keys = {"imsak","fajr","sunrise","dhuhr","asr","maghrib","isha","midnight","lastThird"};
                        for (int i = 0; i < 9; i++) {
                            sb.append(",\"").append(keys[i]).append("\":");
                            if (r.times[i] == null) sb.append("null");
                            else sb.append('"').append(r.times[i].format(DateTimeFormatter.ofPattern("HH:mm:ss"))).append('"');
                        }
                        sb.append('}');
                    }
                }
            }
        }
        sb.append("\n]\n");
        Path out = Paths.get(outDir, "prayer_times_fixtures.json");
        Files.writeString(out, sb.toString());
        System.out.println("Wrote " + out.toAbsolutePath());

        // Hijri fixtures
        StringBuilder hb = new StringBuilder();
        hb.append("[\n");
        boolean firstH = true;
        int[][] hijriCases = {
            {2000, 1, 1}, {2025, 3, 1}, {2025, 6, 6}, {2025, 12, 8},
            {2026, 5, 2}, {1990, 4, 26}, {2030, 1, 15}, {1900, 1, 1}
        };
        for (int[] c : hijriCases) {
            int[] h = gregorianToHijri(c[0], c[1], c[2]);
            if (!firstH) hb.append(",\n");
            firstH = false;
            hb.append("  {\"gy\":").append(c[0]).append(",\"gm\":").append(c[1]).append(",\"gd\":").append(c[2])
              .append(",\"hy\":").append(h[0]).append(",\"hm\":").append(h[1]).append(",\"hd\":").append(h[2]).append('}');
        }
        hb.append("\n]\n");
        Path hOut = Paths.get(outDir, "hijri_fixtures.json");
        Files.writeString(hOut, hb.toString());
        System.out.println("Wrote " + hOut.toAbsolutePath());
    }
}
