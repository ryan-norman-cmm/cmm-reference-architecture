# Patient Matching in FHIR

## Introduction

Patient matching is the process of identifying and linking patient records across different systems and data sources. In healthcare, accurate patient matching is critical for providing comprehensive care, avoiding duplicate records, and ensuring data integrity. This guide explains how to implement effective patient matching algorithms in FHIR systems, covering deterministic and probabilistic matching approaches, handling demographic variations, and configuring match thresholds.

### Quick Start

1. Define your patient matching strategy based on available demographic data
2. Implement deterministic matching for exact matches on reliable identifiers
3. Add probabilistic matching for handling variations in demographic data
4. Configure match thresholds and confidence scores
5. Implement a review process for potential matches that require manual verification

### Related Components

- [Data Tagging in FHIR](data-tagging-in-fhir.md): Learn about resource tagging for tracking data sources
- [Golden Record Management](fhir-golden-records.md) (Coming Soon): Create and maintain master patient records
- [Identity Linking](fhir-identity-linking.md) (Coming Soon): Link patient identities across systems
- [Patient Consent Management](fhir-consent-management.md) (Coming Soon): Manage patient consent preferences

## Deterministic vs. Probabilistic Matching

Patient matching algorithms generally fall into two categories: deterministic and probabilistic.

### Deterministic Matching

Deterministic matching uses exact matches on specific identifiers to link patient records. This approach is straightforward but can miss matches due to data entry errors or variations.

```typescript
import { AidboxClient } from '@aidbox/sdk-r4';
import { Patient } from '@aidbox/sdk-r4/types';

const client = new AidboxClient({
  baseUrl: 'http://localhost:8888',
  auth: {
    type: 'basic',
    username: 'root',
    password: 'secret'
  }
});

/**
 * Performs deterministic matching based on exact identifier matches
 * @param identifiers Array of identifiers to match on
 * @returns Array of matching Patient resources
 */
async function findPatientsByIdentifiers(
  identifiers: Array<{
    system: string;
    value: string;
  }>
): Promise<Patient[]> {
  try {
    // Create an array to hold all matching patients
    const matchingPatients: Patient[] = [];
    
    // Search for each identifier
    for (const identifier of identifiers) {
      const bundle = await client.search<Patient>({
        resourceType: 'Patient',
        params: {
          identifier: `${identifier.system}|${identifier.value}`
        }
      });
      
      // Add matching patients to the array
      if (bundle.entry && bundle.entry.length > 0) {
        bundle.entry.forEach(entry => {
          const patient = entry.resource as Patient;
          // Check if this patient is already in the results
          const exists = matchingPatients.some(p => p.id === patient.id);
          if (!exists) {
            matchingPatients.push(patient);
          }
        });
      }
    }
    
    return matchingPatients;
  } catch (error) {
    console.error('Error finding patients by identifiers:', error);
    throw error;
  }
}

/**
 * Performs deterministic matching based on multiple demographic fields
 * @param demographics The demographic data to match on
 * @returns Array of matching Patient resources
 */
async function findPatientsByDemographics(
  demographics: {
    familyName?: string;
    givenName?: string;
    birthDate?: string;
    gender?: string;
    postalCode?: string;
  }
): Promise<Patient[]> {
  try {
    // Build search parameters
    const params: Record<string, string> = {};
    
    if (demographics.familyName) {
      params['family'] = demographics.familyName;
    }
    
    if (demographics.givenName) {
      params['given'] = demographics.givenName;
    }
    
    if (demographics.birthDate) {
      params['birthdate'] = demographics.birthDate;
    }
    
    if (demographics.gender) {
      params['gender'] = demographics.gender;
    }
    
    if (demographics.postalCode) {
      params['address-postalcode'] = demographics.postalCode;
    }
    
    // Perform the search
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params
    });
    
    return bundle.entry?.map(entry => entry.resource as Patient) || [];
  } catch (error) {
    console.error('Error finding patients by demographics:', error);
    throw error;
  }
}
```

### Probabilistic Matching

Probabilistic matching assigns weights to different data elements and calculates a match probability score. This approach is more flexible and can handle variations in data.

```typescript
/**
 * Calculates string similarity using Levenshtein distance
 * @param str1 First string
 * @param str2 Second string
 * @returns Similarity score between 0 and 1
 */
function calculateStringSimilarity(str1: string, str2: string): number {
  if (!str1 || !str2) return 0;
  
  // Convert to lowercase for case-insensitive comparison
  const s1 = str1.toLowerCase();
  const s2 = str2.toLowerCase();
  
  // Calculate Levenshtein distance
  const matrix: number[][] = [];
  
  // Initialize matrix
  for (let i = 0; i <= s1.length; i++) {
    matrix[i] = [i];
  }
  
  for (let j = 0; j <= s2.length; j++) {
    matrix[0][j] = j;
  }
  
  // Fill matrix
  for (let i = 1; i <= s1.length; i++) {
    for (let j = 1; j <= s2.length; j++) {
      const cost = s1.charAt(i - 1) === s2.charAt(j - 1) ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,      // deletion
        matrix[i][j - 1] + 1,      // insertion
        matrix[i - 1][j - 1] + cost // substitution
      );
    }
  }
  
  // Calculate similarity score
  const distance = matrix[s1.length][s2.length];
  const maxLength = Math.max(s1.length, s2.length);
  
  return maxLength === 0 ? 1 : 1 - distance / maxLength;
}

/**
 * Calculates date similarity
 * @param date1 First date string (YYYY-MM-DD)
 * @param date2 Second date string (YYYY-MM-DD)
 * @returns Similarity score between 0 and 1
 */
function calculateDateSimilarity(date1: string, date2: string): number {
  if (!date1 || !date2) return 0;
  
  try {
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    
    // Calculate difference in days
    const diffTime = Math.abs(d2.getTime() - d1.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    // Score based on difference in days
    if (diffDays === 0) return 1; // Exact match
    if (diffDays <= 5) return 0.9; // Within 5 days (possible data entry error)
    if (diffDays <= 30) return 0.7; // Within a month
    if (diffDays <= 365) return 0.3; // Within a year
    
    return 0; // More than a year difference
  } catch (error) {
    return 0; // Invalid date format
  }
}

/**
 * Performs probabilistic matching on a patient record
 * @param patientData The patient data to match
 * @param threshold The minimum match score to consider a match
 * @returns Array of potential matches with scores
 */
async function findProbabilisticMatches(
  patientData: {
    familyName?: string;
    givenNames?: string[];
    birthDate?: string;
    gender?: string;
    postalCode?: string;
    phoneNumber?: string;
  },
  threshold: number = 0.8
): Promise<Array<{ patient: Patient; score: number }>> {
  try {
    // Define field weights
    const weights = {
      familyName: 0.3,
      givenName: 0.2,
      birthDate: 0.3,
      gender: 0.05,
      postalCode: 0.1,
      phoneNumber: 0.05
    };
    
    // Build initial search parameters for candidate selection
    // Use a broader search to get potential candidates
    const params: Record<string, string> = {};
    
    if (patientData.familyName) {
      // Use the first 3 characters for a broader match
      params['family:contains'] = patientData.familyName.substring(0, 3);
    }
    
    if (patientData.birthDate) {
      // Use birth year for broader match
      const birthYear = patientData.birthDate.substring(0, 4);
      params['birthdate:contains'] = birthYear;
    }
    
    if (patientData.gender) {
      params['gender'] = patientData.gender;
    }
    
    // Perform the initial search to get candidates
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params
    });
    
    const candidates = bundle.entry?.map(entry => entry.resource as Patient) || [];
    
    // Calculate match scores for each candidate
    const matches: Array<{ patient: Patient; score: number }> = [];
    
    for (const candidate of candidates) {
      let totalScore = 0;
      let totalWeight = 0;
      
      // Family name comparison
      if (patientData.familyName && candidate.name?.[0]?.family) {
        const familyNameScore = calculateStringSimilarity(
          patientData.familyName,
          candidate.name[0].family
        );
        totalScore += familyNameScore * weights.familyName;
        totalWeight += weights.familyName;
      }
      
      // Given name comparison
      if (patientData.givenNames && patientData.givenNames.length > 0 && 
          candidate.name?.[0]?.given && candidate.name[0].given.length > 0) {
        let bestGivenNameScore = 0;
        
        // Compare each given name and take the best match
        for (const givenName1 of patientData.givenNames) {
          for (const givenName2 of candidate.name[0].given) {
            const score = calculateStringSimilarity(givenName1, givenName2);
            bestGivenNameScore = Math.max(bestGivenNameScore, score);
          }
        }
        
        totalScore += bestGivenNameScore * weights.givenName;
        totalWeight += weights.givenName;
      }
      
      // Birth date comparison
      if (patientData.birthDate && candidate.birthDate) {
        const birthDateScore = calculateDateSimilarity(
          patientData.birthDate,
          candidate.birthDate
        );
        totalScore += birthDateScore * weights.birthDate;
        totalWeight += weights.birthDate;
      }
      
      // Gender comparison
      if (patientData.gender && candidate.gender) {
        const genderScore = patientData.gender === candidate.gender ? 1 : 0;
        totalScore += genderScore * weights.gender;
        totalWeight += weights.gender;
      }
      
      // Postal code comparison
      if (patientData.postalCode && candidate.address?.[0]?.postalCode) {
        const postalCodeScore = calculateStringSimilarity(
          patientData.postalCode,
          candidate.address[0].postalCode
        );
        totalScore += postalCodeScore * weights.postalCode;
        totalWeight += weights.postalCode;
      }
      
      // Phone number comparison
      if (patientData.phoneNumber && candidate.telecom) {
        const phoneNumbers = candidate.telecom
          .filter(t => t.system === 'phone')
          .map(t => t.value || '');
        
        let bestPhoneScore = 0;
        for (const phone of phoneNumbers) {
          const score = calculateStringSimilarity(
            patientData.phoneNumber,
            phone
          );
          bestPhoneScore = Math.max(bestPhoneScore, score);
        }
        
        totalScore += bestPhoneScore * weights.phoneNumber;
        totalWeight += weights.phoneNumber;
      }
      
      // Calculate final score
      const finalScore = totalWeight > 0 ? totalScore / totalWeight : 0;
      
      // Add to matches if above threshold
      if (finalScore >= threshold) {
        matches.push({
          patient: candidate,
          score: finalScore
        });
      }
    }
    
    // Sort matches by score (highest first)
    return matches.sort((a, b) => b.score - a.score);
  } catch (error) {
    console.error('Error finding probabilistic matches:', error);
    throw error;
  }
}
```

## Handling Name Variations and Demographic Differences

Patient demographic data often contains variations and differences that can complicate matching.

### Name Normalization

```typescript
/**
 * Normalizes a name for better matching
 * @param name The name to normalize
 * @returns Normalized name
 */
function normalizeName(name: string): string {
  if (!name) return '';
  
  // Convert to lowercase
  let normalized = name.toLowerCase();
  
  // Remove common prefixes and suffixes
  const prefixes = ['mr', 'mrs', 'ms', 'dr', 'prof'];
  const suffixes = ['jr', 'sr', 'ii', 'iii', 'iv', 'md', 'phd'];
  
  for (const prefix of prefixes) {
    normalized = normalized.replace(new RegExp(`^${prefix}\.?\s+`), '');
  }
  
  for (const suffix of suffixes) {
    normalized = normalized.replace(new RegExp(`\s+${suffix}\.?$`), '');
  }
  
  // Remove special characters and extra spaces
  normalized = normalized.replace(/[^a-z0-9]/g, ' ').replace(/\s+/g, ' ').trim();
  
  return normalized;
}

/**
 * Normalizes a phone number for better matching
 * @param phone The phone number to normalize
 * @returns Normalized phone number
 */
function normalizePhoneNumber(phone: string): string {
  if (!phone) return '';
  
  // Remove all non-digit characters
  return phone.replace(/\D/g, '');
}

/**
 * Enhanced patient matching with normalization
 * @param patientData The patient data to match
 * @returns Array of potential matches with scores
 */
async function enhancedPatientMatching(
  patientData: {
    familyName?: string;
    givenNames?: string[];
    birthDate?: string;
    gender?: string;
    postalCode?: string;
    phoneNumber?: string;
  }
): Promise<Array<{ patient: Patient; score: number }>> {
  // Normalize input data
  const normalizedData = {
    familyName: patientData.familyName ? normalizeName(patientData.familyName) : undefined,
    givenNames: patientData.givenNames ? patientData.givenNames.map(normalizeName) : undefined,
    birthDate: patientData.birthDate,
    gender: patientData.gender,
    postalCode: patientData.postalCode ? patientData.postalCode.replace(/\s+/g, '') : undefined,
    phoneNumber: patientData.phoneNumber ? normalizePhoneNumber(patientData.phoneNumber) : undefined
  };
  
  // Perform probabilistic matching with normalized data
  return await findProbabilisticMatches(normalizedData, 0.7);
}
```

### Phonetic Matching

Phonetic algorithms like Soundex and Metaphone can help match names that sound similar but are spelled differently.

```typescript
/**
 * Generates a Soundex code for a string
 * @param str The string to encode
 * @returns Soundex code
 */
function soundex(str: string): string {
  if (!str) return '';
  
  // Convert to uppercase
  const s = str.toUpperCase();
  
  // Keep first letter
  let result = s[0];
  
  // Map consonants to digits
  const map: Record<string, string> = {
    B: '1', F: '1', P: '1', V: '1',
    C: '2', G: '2', J: '2', K: '2', Q: '2', S: '2', X: '2', Z: '2',
    D: '3', T: '3',
    L: '4',
    M: '5', N: '5',
    R: '6'
  };
  
  // Previous digit
  let prevDigit = '';
  
  // Process remaining characters
  for (let i = 1; i < s.length; i++) {
    const c = s[i];
    const digit = map[c] || '';
    
    // Skip vowels and H, W, Y
    if (digit && digit !== prevDigit) {
      result += digit;
      prevDigit = digit;
    }
    
    // Stop when we have a letter and 3 digits
    if (result.length >= 4) {
      break;
    }
  }
  
  // Pad with zeros if necessary
  result = result.padEnd(4, '0');
  
  return result;
}

/**
 * Performs phonetic matching on patient names
 * @param name The name to match
 * @returns Array of matching Patient resources
 */
async function findPatientsByPhoneticName(name: string): Promise<Patient[]> {
  try {
    // Generate Soundex code for the input name
    const nameCode = soundex(name);
    
    // Search for patients
    const bundle = await client.search<Patient>({
      resourceType: 'Patient',
      params: {}
    });
    
    const patients = bundle.entry?.map(entry => entry.resource as Patient) || [];
    
    // Filter patients by Soundex code
    return patients.filter(patient => {
      // Check family name
      const familyName = patient.name?.[0]?.family || '';
      const familyCode = soundex(familyName);
      
      if (familyCode === nameCode) {
        return true;
      }
      
      // Check given names
      const givenNames = patient.name?.[0]?.given || [];
      for (const givenName of givenNames) {
        const givenCode = soundex(givenName);
        if (givenCode === nameCode) {
          return true;
        }
      }
      
      return false;
    });
  } catch (error) {
    console.error('Error finding patients by phonetic name:', error);
    throw error;
  }
}
```

## Configuring Match Thresholds and Confidence Scores

Properly configured match thresholds are essential for balancing false positives and false negatives.

### Match Confidence Levels

```typescript
/**
 * Match confidence level
 */
enum MatchConfidence {
  DEFINITE = 'DEFINITE', // Automatic match
  PROBABLE = 'PROBABLE', // Likely match, but requires review
  POSSIBLE = 'POSSIBLE', // Possible match, requires review
  UNLIKELY = 'UNLIKELY'  // Not a match
}

/**
 * Determines match confidence level based on score
 * @param score The match score
 * @returns Match confidence level
 */
function getMatchConfidence(score: number): MatchConfidence {
  if (score >= 0.95) return MatchConfidence.DEFINITE;
  if (score >= 0.85) return MatchConfidence.PROBABLE;
  if (score >= 0.75) return MatchConfidence.POSSIBLE;
  return MatchConfidence.UNLIKELY;
}

/**
 * Performs patient matching with confidence levels
 * @param patientData The patient data to match
 * @returns Matches grouped by confidence level
 */
async function matchPatientWithConfidence(
  patientData: {
    familyName?: string;
    givenNames?: string[];
    birthDate?: string;
    gender?: string;
    postalCode?: string;
    phoneNumber?: string;
  }
): Promise<Record<MatchConfidence, Array<{ patient: Patient; score: number }>>> {
  try {
    // Get all potential matches with scores
    const matches = await enhancedPatientMatching(patientData);
    
    // Group by confidence level
    const result: Record<MatchConfidence, Array<{ patient: Patient; score: number }>> = {
      [MatchConfidence.DEFINITE]: [],
      [MatchConfidence.PROBABLE]: [],
      [MatchConfidence.POSSIBLE]: [],
      [MatchConfidence.UNLIKELY]: []
    };
    
    for (const match of matches) {
      const confidence = getMatchConfidence(match.score);
      result[confidence].push(match);
    }
    
    return result;
  } catch (error) {
    console.error('Error matching patient with confidence:', error);
    throw error;
  }
}
```

### Tuning Match Thresholds

```typescript
/**
 * Match threshold configuration
 */
interface MatchThresholds {
  definite: number;
  probable: number;
  possible: number;
}

/**
 * Default match thresholds
 */
const defaultThresholds: MatchThresholds = {
  definite: 0.95,
  probable: 0.85,
  possible: 0.75
};

/**
 * Strict match thresholds (fewer false positives)
 */
const strictThresholds: MatchThresholds = {
  definite: 0.98,
  probable: 0.90,
  possible: 0.80
};

/**
 * Relaxed match thresholds (fewer false negatives)
 */
const relaxedThresholds: MatchThresholds = {
  definite: 0.90,
  probable: 0.80,
  possible: 0.70
};

/**
 * Determines match confidence level based on score and thresholds
 * @param score The match score
 * @param thresholds The threshold configuration
 * @returns Match confidence level
 */
function getMatchConfidenceWithThresholds(
  score: number,
  thresholds: MatchThresholds = defaultThresholds
): MatchConfidence {
  if (score >= thresholds.definite) return MatchConfidence.DEFINITE;
  if (score >= thresholds.probable) return MatchConfidence.PROBABLE;
  if (score >= thresholds.possible) return MatchConfidence.POSSIBLE;
  return MatchConfidence.UNLIKELY;
}

/**
 * Performs patient matching with configurable thresholds
 * @param patientData The patient data to match
 * @param thresholds The threshold configuration
 * @returns Matches grouped by confidence level
 */
async function matchPatientWithThresholds(
  patientData: {
    familyName?: string;
    givenNames?: string[];
    birthDate?: string;
    gender?: string;
    postalCode?: string;
    phoneNumber?: string;
  },
  thresholds: MatchThresholds = defaultThresholds
): Promise<Record<MatchConfidence, Array<{ patient: Patient; score: number }>>> {
  try {
    // Get all potential matches with scores
    const matches = await enhancedPatientMatching(patientData);
    
    // Group by confidence level
    const result: Record<MatchConfidence, Array<{ patient: Patient; score: number }>> = {
      [MatchConfidence.DEFINITE]: [],
      [MatchConfidence.PROBABLE]: [],
      [MatchConfidence.POSSIBLE]: [],
      [MatchConfidence.UNLIKELY]: []
    };
    
    for (const match of matches) {
      const confidence = getMatchConfidenceWithThresholds(match.score, thresholds);
      result[confidence].push(match);
    }
    
    return result;
  } catch (error) {
    console.error('Error matching patient with thresholds:', error);
    throw error;
  }
}
```

## Conclusion

Effective patient matching is essential for maintaining data integrity and providing comprehensive care in healthcare systems. By implementing a combination of deterministic and probabilistic matching algorithms, handling demographic variations, and configuring appropriate match thresholds, you can create a robust patient matching system that minimizes both false positives and false negatives.

Key takeaways:

1. Use deterministic matching for exact matches on reliable identifiers
2. Implement probabilistic matching to handle variations in demographic data
3. Normalize and standardize patient data before matching
4. Consider phonetic algorithms for name matching
5. Configure match thresholds based on your organization's tolerance for false positives and false negatives

By following these guidelines, you can create a patient matching system that effectively identifies and links patient records across different systems and data sources.
