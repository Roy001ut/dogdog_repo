package dogapi;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.*;
import java.util.prefs.BackingStoreException;

/**
 * BreedFetcher implementation that relies on the dog.ceo API.
 * Note that all failures get reported as BreedNotFoundException
 * exceptions to align with the requirements of the BreedFetcher interface.
 */
public class DogApiBreedFetcher implements BreedFetcher {
    private final OkHttpClient client = new OkHttpClient();

    /**
     * Fetch the list of sub breeds for the given breed from the dog.ceo API.
     * @param breed the breed to fetch sub breeds for
     * @return list of sub breeds for the given breed
     * @throws BreedNotFoundException if the breed does not exist (or if the API call fails for any reason)
     */
    @Override
    public List<String> getSubBreeds(String breed) throws BreedNotFoundException {
        // TODO Task 1: Complete this method based on its provided documentation
        //      and the documentation for the dog.ceo API. You may find it helpful
        //      to refer to the examples of using OkHttpClient from the last lab,
        //      as well as the code for parsing JSON responses.
        // return statement included so that the starter code can compile and run.
        String url = "https://dog.ceo/api/breed/" + breed + "/list";
        final Request request = new Request.Builder()
                .url(url)
                .get()
                .build();

        try(Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new BreedNotFoundException("API response invalid");
            }

            String bodyStr = (response.body() == null) ? "" : response.body().string();

            if (bodyStr.isEmpty()){
                throw new BreedNotFoundException("Empty response");
                }

            JSONObject obj = new JSONObject(bodyStr);
            String status = obj.optString("status", "");

            if (status.equalsIgnoreCase("error")){
                throw new BreedNotFoundException("error case happen");
            }

            JSONArray array = obj.getJSONArray("message");
            List<String> subBreeds = new ArrayList<>();

            for (int i = 0; i < array.length(); i++ ){
                subBreeds.add(array.getString(i));
            }
            return subBreeds;

        }catch (IOException | JSONException e) {
            throw new BreedNotFoundException("error from somewhere");

        }
    }
}