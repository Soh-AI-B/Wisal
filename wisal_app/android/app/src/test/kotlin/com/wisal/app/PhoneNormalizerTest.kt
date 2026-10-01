package com.wisal.app

import org.junit.Assert.assertEquals
import org.junit.Test

class PhoneNormalizerTest {
    private val expected = "213550123456"

    @Test fun localFormats() {
        assertEquals(expected, PhoneNormalizer.normalize("0550 12 34 56"))
        assertEquals(expected, PhoneNormalizer.normalize("0550123456"))
        assertEquals(expected, PhoneNormalizer.normalize("550123456"))
    }

    @Test fun internationalFormats() {
        assertEquals(expected, PhoneNormalizer.normalize("+213550123456"))
        assertEquals(expected, PhoneNormalizer.normalize("+213 550 12 34 56"))
        assertEquals(expected, PhoneNormalizer.normalize("00213550123456"))
        assertEquals(expected, PhoneNormalizer.normalize("213550123456"))
    }

    @Test fun otherCountriesAndEmpty() {
        assertEquals("33612345678", PhoneNormalizer.normalize("+33 6 12 34 56 78"))
        assertEquals("", PhoneNormalizer.normalize(""))
        assertEquals("", PhoneNormalizer.normalize(null))
    }
}
