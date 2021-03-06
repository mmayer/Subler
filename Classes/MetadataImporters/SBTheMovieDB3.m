//
//  TheMovieDB3.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBMetadataSearchController.h"

#import "SBTheMovieDB3.h"
#import "SBiTunesStore.h"

#define API_KEY @"b0073bafb08b4f68df101eb2325f27dc"

@implementation SBTheMovieDB3

- (NSArray<NSString *> *)languages
{
	return [[MP42Languages defaultManager] iso6391languages];
}

- (NSArray *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage
{
	NSString *lang = [MP42Languages iso6391CodeFor:aLanguage];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/search/movie?api_key=%@&query=%@&language=%@",
                                       API_KEY, [SBMetadataHelper urlEncoded:aMovieTitle], lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            return [SBTheMovieDB3 metadataForResults:d];
        }
	}

	return nil;
}

- (MP42Metadata *)artworksForResult:(NSDictionary *)r metadata:(MP42Metadata *)aMetadata
{
    // artwork
	NSMutableArray *artworkThumbURLs = [NSMutableArray array];
	NSMutableArray *artworkFullsizeURLs = [NSMutableArray array];
	NSMutableArray *artworkProviderNames = [NSMutableArray array];

    // add iTunes artwork
    MP42Metadata *iTunesMetadata = [SBiTunesStore quickiTunesSearchMovie:aMetadata.tagsDict[@"Name"]];

	if (iTunesMetadata && iTunesMetadata.artworkThumbURLs && iTunesMetadata.artworkFullsizeURLs &&
        (iTunesMetadata.artworkThumbURLs.count == iTunesMetadata.artworkFullsizeURLs.count)) {

		[artworkThumbURLs addObjectsFromArray:[iTunesMetadata artworkThumbURLs]];
		[artworkFullsizeURLs addObjectsFromArray:[iTunesMetadata artworkFullsizeURLs]];
		[artworkProviderNames addObjectsFromArray:[iTunesMetadata artworkProviderNames]];
	}

    // load image variables from configuration
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/configuration?api_key=%@", API_KEY]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
    NSArray *posters = r[@"images"][@"posters"];

    if (jsonData && posters && [posters isKindOfClass:[NSArray class]]) {
        NSDictionary *config = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

		if ([config isKindOfClass:[NSDictionary class]] && config[@"images"]) {
			NSString *imageBaseUrl = config[@"images"][@"secure_base_url"];
			NSString *posterThumbnailSize = [config[@"images"][@"poster_sizes"] firstObject];
			NSString *backdropThumbnailSize = [config[@"images"][@"backdrop_sizes"] firstObject];

            for (NSDictionary *poster in posters) {
                if (poster[@"file_path"] && (poster[@"file_path"] != [NSNull null])) {
                    [artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, poster[@"file_path"]]]];
                    [artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", poster[@"file_path"]]]];
                    [artworkProviderNames addObject:@"TheMovieDB|poster"];
                }
            }
            if (!posters.count && r[@"poster_path"] && (r[@"poster_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, r[@"poster_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", r[@"poster_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|poster"];
			}

			if (r[@"backdrop_path"] && (r[@"backdrop_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, backdropThumbnailSize, r[@"backdrop_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", r[@"backdrop_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|backdrop"];
			}
		}

    }

    aMetadata.artworkThumbURLs = artworkThumbURLs;
    aMetadata.artworkFullsizeURLs = artworkFullsizeURLs;
    aMetadata.artworkProviderNames = artworkProviderNames;

    return aMetadata;
}

- (MP42Metadata *)loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage
{
	NSString *lang = [MP42Languages iso6391CodeFor:aLanguage];
	NSNumber *theMovieDBID = aMetadata.tagsDict[@"TheMovieDB ID"];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/movie/%@?api_key=%@&language=%@&append_to_response=casts,releases,images",
                                       theMovieDBID, API_KEY, lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {

            MP42Metadata *r = [SBTheMovieDB3 metadataForResult:d language:lang];
            if (r) {
                [aMetadata mergeMetadata:r];
            }
            aMetadata = [self artworksForResult:d metadata:aMetadata];
        }
	}

	return aMetadata;
}

#pragma mark Parse results

+ (NSString *)commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey {
	if (aArray.count == 0) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray arrayWithCapacity:aArray.count];
	for (NSDictionary *d in aArray) {
		if (d[aKey]) {
			[r addObject:d[aKey]];
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (NSString *)commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey withKey:(NSString *)aWithKey equalTo:(NSString *)aEqualTo {
	if (aArray.count == 0) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray array];
	for (NSDictionary *d in aArray) {
		if (d[aKey]) {
			if ([d[aWithKey] isEqualToString:aEqualTo]) {
				[r addObject:d[aKey]];
			}
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (MP42Metadata *)metadataForResult:(NSDictionary<NSString *, id> *)r language:(NSString *)language
{
	MP42Metadata *metadata = [[MP42Metadata alloc] init];

	metadata.mediaKind = 9; // movie
    metadata[@"TheMovieDB ID"]      = r[@"id"];
    metadata[@"Name"]               = r[@"title"];
    metadata[@"Release Date"]       = r[@"release_date"];
    metadata[@"Genre"]              = [SBTheMovieDB3 commaJoinedSubentriesOf:r[@"genres"] forKey:@"name"];
    metadata[@"Description"]        = r[@"overview"];
    metadata[@"Long Description"]   = r[@"overview"];
    metadata[@"Studio"]             = [SBTheMovieDB3 commaJoinedSubentriesOf:r[@"production_companies"] forKey:@"name"];

    NSDictionary<NSString *, NSArray *> *casts = r[@"casts"];
    metadata[@"Cast"]                   = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"cast"] forKey:@"name"];
    metadata[@"Director"]               = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"];
    metadata[@"Artist"]                 = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"];
    metadata[@"Producers"]              = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Producer"];
    metadata[@"Executive Producer"]     = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Executive Producer"];
    metadata[@"Screenwriters"]          = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"department" equalTo:@"Writing"];
    metadata[@"Composer"]               = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Original Music Composer"];

    if (language) {
        NSArray<NSDictionary *> *countries = r[@"releases"][@"countries"];

        for (NSDictionary *d in countries) {
            if ([d[@"iso_3166_1"] isEqualToString:@"US"]) {
                metadata[@"Rating"] = @([[MP42Ratings defaultManager] ratingIndexForiTunesCountry:@"USA" media:@"movie" ratingString:d[@"certification"]]);
            }
        }
    }

    return [metadata autorelease];
}

+ (NSArray<MP42Metadata *> *)metadataForResults:(NSDictionary *)dict
{
	NSArray *resultsArray = dict[@"results"];
    NSMutableArray<MP42Metadata *> *returnArray = [NSMutableArray array];

	for (NSDictionary *r in resultsArray) {
        if ([r isKindOfClass:[NSDictionary class]]) {
            MP42Metadata *metadata = [SBTheMovieDB3 metadataForResult:r language:nil];
            [returnArray addObject:metadata];
        }
	}

    return returnArray;
}

@end
